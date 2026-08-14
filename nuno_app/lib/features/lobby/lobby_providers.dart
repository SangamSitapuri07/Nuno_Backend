import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/json.dart';
import '../../data/models/room_models.dart';
import '../../data/models/social_models.dart';
import '../../services/socket_events.dart';
import '../../services/socket_service.dart';

@immutable
class LobbyState {
  final GameRoom? room;
  final List<ChatMessage> messages;
  final int? countdown;
  final String? error;
  final bool isConnecting;
  final bool wasKicked;
  final bool gameStarted;

  const LobbyState({
    this.room,
    this.messages = const [],
    this.countdown,
    this.error,
    this.isConnecting = false,
    this.wasKicked = false,
    this.gameStarted = false,
  });

  LobbyState copyWith({
    GameRoom? room,
    List<ChatMessage>? messages,
    int? countdown,
    String? error,
    bool? isConnecting,
    bool? wasKicked,
    bool? gameStarted,
    bool clearCountdown = false,
    bool clearError = false,
    bool clearRoom = false,
  }) =>
      LobbyState(
        room: clearRoom ? null : (room ?? this.room),
        messages: messages ?? this.messages,
        countdown: clearCountdown ? null : (countdown ?? this.countdown),
        error: clearError ? null : (error ?? this.error),
        isConnecting: isConnecting ?? this.isConnecting,
        wasKicked: wasKicked ?? this.wasKicked,
        gameStarted: gameStarted ?? this.gameStarted,
      );

  bool get isInRoom => room != null;
  bool get isCountingDown => countdown != null;
}

/// Drives room.create / room.join / room.ready / room.kick and mirrors the
/// server's room.updated broadcasts (see src/rooms/room.handler.ts).
class LobbyController extends StateNotifier<LobbyState> {
  final Ref _ref;
  final List<StreamSubscription> _subs = [];

  LobbyController(this._ref) : super(const LobbyState()) {
    _listen();
  }

  SocketService get _socket => _ref.read(socketServiceProvider);

  void _listen() {
    void sub(String event, void Function(Map<String, dynamic>) handler) {
      _subs.add(_socket.on(event).listen(handler));
    }

    sub(SocketEvents.roomCreated, (p) {
      final room = GameRoom.fromJson(J.map(p['room']));
      state = state.copyWith(
        room: room,
        isConnecting: false,
        clearError: true,
        messages: [ChatMessage.system('Room created. Share code ${room.roomCode}')],
      );
    });

    sub(SocketEvents.roomJoined, (p) {
      state = state.copyWith(
        room: GameRoom.fromJson(J.map(p['room'])),
        isConnecting: false,
        clearError: true,
      );
    });

    sub(SocketEvents.roomUpdated, (p) {
      state = state.copyWith(
        room: GameRoom.fromJson(J.map(p['room'])),
        isConnecting: false,
      );
    });

    sub(SocketEvents.roomLeft, (_) {
      state = const LobbyState();
    });

    sub(SocketEvents.roomKicked, (p) {
      state = LobbyState(
        wasKicked: true,
        error: J.str(p['reason'], 'You were removed from the room.'),
      );
    });

    sub(SocketEvents.roomHostChanged, (p) {
      final newHost = J.str(p['newHost']);
      final name = state.room?.playerById(newHost)?.username ?? 'A player';
      _appendMessage(ChatMessage.system('$name is now the host'));
    });

    sub(SocketEvents.roomCountdown, (p) {
      state = state.copyWith(countdown: J.int_(p['count']));
    });

    sub(SocketEvents.roomCountdownCancelled, (p) {
      state = state.copyWith(clearCountdown: true);
      _appendMessage(
        ChatMessage.system(J.str(p['reason'], 'Countdown cancelled')),
      );
    });

    sub(SocketEvents.gameStarted, (_) {
      state = state.copyWith(gameStarted: true, clearCountdown: true);
    });

    sub(SocketEvents.chatReceived, (p) {
      _appendMessage(ChatMessage.fromJson(p));
    });

    sub(SocketEvents.error, (p) {
      state = state.copyWith(
        error: J.str(p['message'], 'Something went wrong.'),
        isConnecting: false,
      );
    });
  }

  void _appendMessage(ChatMessage message) {
    final next = [...state.messages, message];
    // Keep the buffer bounded.
    state = state.copyWith(
      messages: next.length > 100 ? next.sublist(next.length - 100) : next,
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  void createRoom({
    GameMode mode = GameMode.private,
    int maxPlayers = 4,
    bool voiceEnabled = true,
  }) {
    state = const LobbyState(isConnecting: true);
    _socket.emit(SocketEvents.roomCreate, {
      'gameMode': mode.wire,
      'maxPlayers': maxPlayers,
      'voiceEnabled': voiceEnabled,
    });
  }

  void joinRoom(String roomCode) {
    state = const LobbyState(isConnecting: true);
    _socket.emit(SocketEvents.roomJoin, {'roomCode': roomCode});
  }

  void setReady(bool isReady) {
    _socket.emit(SocketEvents.roomReady, {'isReady': isReady});
  }

  void kick(String targetUserId) {
    _socket.emit(SocketEvents.roomKick, {'targetUserId': targetUserId});
  }

  void leave() {
    _socket.emit(SocketEvents.roomLeave);
    state = const LobbyState();
  }

  void sendChat(String message) {
    final text = message.trim();
    if (text.isEmpty || text.length > 200) return;
    _socket.emit(SocketEvents.chatSend, {'message': text});
  }

  void invite(String targetUserId) {
    final code = state.room?.roomCode;
    if (code == null) return;
    _socket.emit(SocketEvents.inviteSend, {
      'targetUserId': targetUserId,
      'roomCode': code,
    });
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() => state = const LobbyState();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final lobbyControllerProvider =
    StateNotifierProvider<LobbyController, LobbyState>(
        (ref) => LobbyController(ref));
