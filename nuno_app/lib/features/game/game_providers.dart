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
    bool clearError = false,
    bool clearPending = false,
    bool clearResult = false,
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
      state = const GameUiState(isSyncing: true);
      requestSync();
    });

    sub(SocketEvents.playerDrewCard, (p) {
      final userId = J.strOrNull(p['userId']);
      if (userId == null || userId == _myId) return;
      final name = state.game?.playerInfo(userId).username ?? 'Player';
      final count = J.int_(p['count'], 1);
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

  void requestRematch() => _socket.emit(SocketEvents.rematchRequest);

  void acceptRematch() => _socket.emit(SocketEvents.rematchAccept);

  void declineRematch() => _socket.emit(SocketEvents.rematchDecline);

  void clearError() => state = state.copyWith(clearError: true);

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
