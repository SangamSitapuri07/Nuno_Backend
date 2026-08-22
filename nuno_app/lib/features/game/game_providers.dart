import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_card.dart';
import '../../data/models/game_state.dart';
import '../../data/models/json.dart';
import '../../data/models/social_models.dart';
import '../../services/socket_events.dart';
import '../../services/socket_service.dart';
import '../auth/auth_controller.dart';

/// A transient visual event (emote, UNO call, quick chat) shown over the table.
@immutable
class TableToast {
  final String id;
  final String userId;
  final String username;
  final String text;
  final bool isEmote;

  const TableToast({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    this.isEmote = false,
  });
}

@immutable
class GameUiState {
  final GameState? game;
  final int turnSecondsLeft;
  final List<ChatMessage> messages;
  final List<TableToast> toasts;
  final GameResultPayload? result;
  final String? error;
  final bool isSyncing;
  final Set<String> unoCalledBy;

  /// Set while a play is in flight so the card can't be double-tapped.
  final String? pendingCardId;

  /// Number of cards the local player was just forced to draw (screen 11).
  final int? penaltyDraw;

  /// Who has agreed to play again since the match ended.
  ///
  /// The server already tracked this and started a new match once everyone
  /// had accepted, but the app never listened, so pressing PLAY AGAIN fired
  /// one event into the void and closed the dialog. Holding the votes here
  /// lets the result screen show who is waiting on whom.
  final Set<String> rematchAcceptedBy;

  /// Players who have said no, or left. A rematch can no longer happen.
  final Set<String> rematchDeclinedBy;

  /// Bumped each time the server actually starts a rematch.
  ///
  /// The screen used to infer this from "the result vanished and we are
  /// syncing", which is also true when the player walks out to the lobby and
  /// on some reconnects - so the dialog was dismissed on the wrong events and
  /// left up on the right one. A counter says exactly what happened.
  final int rematchEpoch;

  const GameUiState({
    this.game,
    this.turnSecondsLeft = AppConfig.turnTimerSeconds,
    this.messages = const [],
    this.toasts = const [],
    this.result,
    this.error,
    this.isSyncing = true,
    this.unoCalledBy = const {},
    this.pendingCardId,
    this.penaltyDraw,
    this.rematchAcceptedBy = const {},
    this.rematchDeclinedBy = const {},
    this.rematchEpoch = 0,
  });

  GameUiState copyWith({
    GameState? game,
    int? turnSecondsLeft,
    List<ChatMessage>? messages,
    List<TableToast>? toasts,
    GameResultPayload? result,
    String? error,
    bool? isSyncing,
    Set<String>? unoCalledBy,
    String? pendingCardId,
    int? penaltyDraw,
    Set<String>? rematchAcceptedBy,
    Set<String>? rematchDeclinedBy,
    int? rematchEpoch,
    bool clearError = false,
    bool clearPending = false,
    bool clearResult = false,
    bool clearPenalty = false,
  }) =>
      GameUiState(
        game: game ?? this.game,
        turnSecondsLeft: turnSecondsLeft ?? this.turnSecondsLeft,
        messages: messages ?? this.messages,
        toasts: toasts ?? this.toasts,
        result: clearResult ? null : (result ?? this.result),
        error: clearError ? null : (error ?? this.error),
        isSyncing: isSyncing ?? this.isSyncing,
        unoCalledBy: unoCalledBy ?? this.unoCalledBy,
        pendingCardId: clearPending ? null : (pendingCardId ?? this.pendingCardId),
        penaltyDraw: clearPenalty ? null : (penaltyDraw ?? this.penaltyDraw),
        rematchAcceptedBy: rematchAcceptedBy ?? this.rematchAcceptedBy,
        rematchDeclinedBy: rematchDeclinedBy ?? this.rematchDeclinedBy,
        rematchEpoch: rematchEpoch ?? this.rematchEpoch,
      );

  bool get isFinished => result != null || (game?.isFinished ?? false);
}

/// Owns the live match: mirrors game.syncState, drives card.play / card.draw /
/// uno.call / emotes, and runs the local 20-second turn clock.
class GameController extends StateNotifier<GameUiState> {
  final Ref _ref;
  final List<StreamSubscription> _subs = [];
  Timer? _turnTimer;
  int _toastSeq = 0;

  GameController(this._ref) : super(const GameUiState()) {
    _listen();

    // A sleeping free-tier host drops the socket; on every re-auth the
    // server has forgotten our rooms, so ask for the state again.
    _subs.add(_socket.onAuthenticated.listen((_) => requestSync()));

    requestSync();
  }

  SocketService get _socket => _ref.read(socketServiceProvider);
  String? get _myId => _ref.read(currentUserIdProvider);

  void _listen() {
    void sub(String event, void Function(Map<String, dynamic>) handler) {
      _subs.add(_socket.on(event).listen(handler));
    }

    void applyState(Map<String, dynamic> payload) {
      final game = GameState.fromJson(payload);
      state = state.copyWith(
        game: game,
        isSyncing: false,
        clearPending: true,
        clearError: true,
      );
      _restartTurnTimer();
    }

    sub(SocketEvents.gameInitialState, (p) {
      state = state.copyWith(clearResult: true, unoCalledBy: {});
      applyState(p);
    });

    sub(SocketEvents.gameSyncState, applyState);

    sub(SocketEvents.turnChanged, (p) {
      final remaining = J.int_(p['remainingTime'], AppConfig.turnTimerSeconds);
      state = state.copyWith(turnSecondsLeft: remaining);
      _restartTurnTimer(remaining);
    });

    sub(SocketEvents.gameFinished, (p) {
      _turnTimer?.cancel();
      state = state.copyWith(result: GameResultPayload.fromJson(p));
    });

    sub(SocketEvents.rematchStarted, (_) {
      // Keep the old board until the new one arrives.
      //
      // This used to assign a blank GameUiState, which wiped `game` as well
      // as the result. The results dialog reads the player list off `game`
      // to size its tally, so for the frames between this event and the new
      // hand landing it had nobody to count - and if the fresh state was
      // slow, the screen sat empty. Clearing the result and the votes is
      // enough; the board is replaced wholesale when game.initialState
      // arrives a moment later.
      _turnTimer?.cancel();
      state = state.copyWith(
        isSyncing: true,
        clearResult: true,
        rematchAcceptedBy: const {},
        rematchDeclinedBy: const {},
        rematchEpoch: state.rematchEpoch + 1,
      );
      requestSync();
    });

    // Somebody pressed PLAY AGAIN. The server records the requester as having
    // accepted, so both events mean the same thing to the tally.
    sub(SocketEvents.rematchRequest, (p) {
      final userId = J.strOrNull(p['userId']);
      if (userId == null) return;
      state = state.copyWith(
        rematchAcceptedBy: {...state.rematchAcceptedBy, userId},
      );
    });

    sub(SocketEvents.rematchAccept, (p) {
      final userId = J.strOrNull(p['userId']);
      if (userId == null) return;
      state = state.copyWith(
        rematchAcceptedBy: {...state.rematchAcceptedBy, userId},
      );
    });

    sub(SocketEvents.rematchDecline, (p) {
      final userId = J.strOrNull(p['userId']);
      if (userId == null) return;
      state = state.copyWith(
        rematchDeclinedBy: {...state.rematchDeclinedBy, userId},
      );
    });

    sub(SocketEvents.playerDrewCard, (p) {
      final userId = J.strOrNull(p['userId']);
      final count = J.int_(p['count'], 1);

      // The server sends the payload without `userId` to the drawer itself.
      if (userId == null) {
        // 2+ cards means a +2 / +4 penalty rather than a normal draw.
        if (count >= 2) {
          state = state.copyWith(penaltyDraw: count);
        }
        return;
      }

      if (userId == _myId) return;
      final name = state.game?.playerInfo(userId).username ?? 'Player';
      _pushToast(userId, name, 'drew $count card${count == 1 ? '' : 's'}');
    });

    sub(SocketEvents.directionChanged, (p) {
      final dir = GameDirectionX.parse(J.strOrNull(p['direction']));
      _appendMessage(ChatMessage.system(
        dir == GameDirection.clockwise
            ? 'Direction is now clockwise'
            : 'Direction reversed',
      ));
    });

    sub(SocketEvents.unoCalled, (p) {
      final userId = J.str(p['userId']);
      final name = J.str(p['username'], 'Player');
      state = state.copyWith(unoCalledBy: {...state.unoCalledBy, userId});
      _pushToast(userId, name, 'NUNO!');
    });

    sub(SocketEvents.chatReceived, (p) {
      _appendMessage(ChatMessage.fromJson(p));
    });

    sub(SocketEvents.quickChat, (p) {
      final userId = J.str(p['userId']);
      final name = J.str(p['username'], 'Player');
      _pushToast(userId, name, QuickChat.label(J.str(p['messageType'])));
    });

    sub(SocketEvents.emoteReceived, (p) {
      final userId = J.str(p['userId']);
      final name = J.str(p['username'], 'Player');
      _pushToast(userId, name, Emotes.glyph(J.str(p['emote'])), isEmote: true);
    });

    sub(SocketEvents.error, (p) {
      state = state.copyWith(
        error: J.str(p['message'], 'Something went wrong.'),
        clearPending: true,
      );
    });
  }

  // ── Turn clock ──────────────────────────────────────────────

  void _restartTurnTimer([int? from]) {
    _turnTimer?.cancel();
    var remaining = from ?? AppConfig.turnTimerSeconds;
    state = state.copyWith(turnSecondsLeft: remaining);

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(turnSecondsLeft: 0);
        return;
      }
      state = state.copyWith(turnSecondsLeft: remaining);
    });
  }

  // ── Toasts / chat ───────────────────────────────────────────

  void _pushToast(
    String userId,
    String username,
    String text, {
    bool isEmote = false,
  }) {
    final id = 'toast-${_toastSeq++}';
    final toast = TableToast(
      id: id,
      userId: userId,
      username: username,
      text: text,
      isEmote: isEmote,
    );
    state = state.copyWith(toasts: [...state.toasts, toast]);

    Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      state = state.copyWith(
        toasts: state.toasts.where((t) => t.id != id).toList(),
      );
    });
  }

  void _appendMessage(ChatMessage message) {
    final next = [...state.messages, message];
    state = state.copyWith(
      messages: next.length > 60 ? next.sublist(next.length - 60) : next,
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  void requestSync() {
    state = state.copyWith(isSyncing: true);
    _socket.emit(SocketEvents.gameSyncRequest);
  }

  /// Plays a card. Wild cards require [selectedColor].
  void playCard(GameCard card, {CardColor? selectedColor}) {
    final game = state.game;
    if (game == null) return;
    if (!game.isMyTurn(_myId ?? '')) return;
    if (state.pendingCardId != null) return;

    state = state.copyWith(pendingCardId: card.cardId);

    _socket.emit(SocketEvents.cardPlay, {
      'cardId': card.cardId,
      if (card.isWild && selectedColor != null)
        'selectedColor': selectedColor.wire,
    });
  }

  void drawCard() {
    final game = state.game;
    if (game == null || !game.isMyTurn(_myId ?? '')) return;
    _socket.emit(SocketEvents.cardDraw);
  }

  void callUno() => _socket.emit(SocketEvents.unoCall);

  void surrender() => _socket.emit(SocketEvents.surrender);

  void sendChat(String message) {
    final text = message.trim();
    if (text.isEmpty || text.length > AppConfig.maxChatLength) return;
    _socket.emit(SocketEvents.chatSend, {'message': text});
  }

  void sendQuickChat(String key) =>
      _socket.emit(SocketEvents.quickChat, {'messageType': key});

  void sendEmote(String key) =>
      _socket.emit(SocketEvents.emoteSend, {'emote': key});

  /// Votes to play again.
  ///
  /// Sends `rematch.accept`, not `rematch.request`: on the server both record
  /// the vote, but only accept runs the "has everyone agreed" check that
  /// starts the next match. Emitting request alone meant the last player to
  /// press the button never triggered anything.
  void requestRematch() => _socket.emit(SocketEvents.rematchAccept);

  void acceptRematch() => _socket.emit(SocketEvents.rematchAccept);

  void declineRematch() => _socket.emit(SocketEvents.rematchDecline);

  void clearError() => state = state.copyWith(clearError: true);

  void clearPenalty() => state = state.copyWith(clearPenalty: true);

  void reset() {
    _turnTimer?.cancel();
    state = const GameUiState();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final gameControllerProvider =
    StateNotifierProvider<GameController, GameUiState>(
        (ref) => GameController(ref));

/// True when it's the local player's turn.
final isMyTurnProvider = Provider<bool>((ref) {
  final game = ref.watch(gameControllerProvider).game;
  final myId = ref.watch(currentUserIdProvider);
  if (game == null || myId == null) return false;
  return game.isMyTurn(myId);
});
