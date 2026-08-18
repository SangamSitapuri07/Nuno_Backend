import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/json.dart';
import '../../data/models/room_models.dart';
import '../../services/socket_events.dart';
import '../../services/socket_service.dart';

@immutable
class MatchmakingState {
  final QueueStatus status;
  final GameMode mode;
  final int elapsedSeconds;
  final MatchFoundPayload? match;
  final String? error;

  /// Table size being queued for. Only players who chose the same size are
  /// ever matched together.
  final int tableSize;

  const MatchmakingState({
    this.status = QueueStatus.idle,
    this.mode = GameMode.casual,
    this.elapsedSeconds = 0,
    this.match,
    this.error,
    this.tableSize = 2,
  });

  MatchmakingState copyWith({
    QueueStatus? status,
    GameMode? mode,
    int? elapsedSeconds,
    MatchFoundPayload? match,
    String? error,
    int? tableSize,
    bool clearError = false,
  }) =>
      MatchmakingState(
        status: status ?? this.status,
        mode: mode ?? this.mode,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        match: match ?? this.match,
        error: clearError ? null : (error ?? this.error),
        tableSize: tableSize ?? this.tableSize,
      );

  bool get isSearching => status == QueueStatus.searching;
  bool get isMatchFound => status == QueueStatus.matchFound;

  String get elapsedLabel {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Drives queue.join / queue.leave and listens for match.found
/// (see src/matchmaking/matchmaking.handler.ts).
class MatchmakingController extends StateNotifier<MatchmakingState> {
  final Ref _ref;
  final List<StreamSubscription> _subs = [];
  Timer? _timer;

  MatchmakingController(this._ref) : super(const MatchmakingState()) {
    _listen();
  }

  SocketService get _socket => _ref.read(socketServiceProvider);

  void _listen() {
    void sub(String event, void Function(Map<String, dynamic>) handler) {
      _subs.add(_socket.on(event).listen(handler));
    }

    sub(SocketEvents.queueJoined, (p) {
      state = state.copyWith(
        status: QueueStatus.searching,
        mode: GameModeX.parse(J.strOrNull(p['mode'])),
        tableSize: J.int_(p['requiredPlayers'], state.tableSize),
        elapsedSeconds: 0,
        clearError: true,
      );
      _startTimer();
    });

    sub(SocketEvents.queueLeft, (_) {
      _stopTimer();
      state = const MatchmakingState();
    });

    sub(SocketEvents.matchFound, (p) {
      _stopTimer();
      state = state.copyWith(
        status: QueueStatus.matchFound,
        match: MatchFoundPayload.fromJson(p),
      );
    });

    sub(SocketEvents.gameStarted, (_) {
      _stopTimer();
      state = state.copyWith(status: QueueStatus.inGame);
    });

    sub(SocketEvents.error, (p) {
      final code = J.str(p['code']);
      // Only surface matchmaking-relevant errors here.
      if (code == 'INVALID_MODE' ||
          code == 'ALREADY_IN_QUEUE' ||
          code == 'QUEUE_FULL') {
        _stopTimer();
        state = state.copyWith(
          status: QueueStatus.idle,
          error: J.str(p['message'], 'Matchmaking failed.'),
        );
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void joinQueue(GameMode mode, {int requiredPlayers = 2}) {
    state = state.copyWith(
      status: QueueStatus.searching,
      mode: mode,
      tableSize: requiredPlayers,
      elapsedSeconds: 0,
      clearError: true,
    );
    _startTimer();
    _socket.emit(SocketEvents.queueJoin, {
      'mode': mode.wire,
      'region': 'AUTO',
      'requiredPlayers': requiredPlayers,
    });
  }

  void leaveQueue() {
    _stopTimer();
    _socket.emit(SocketEvents.queueLeave);
    state = const MatchmakingState();
  }

  void reset() {
    _stopTimer();
    state = const MatchmakingState();
  }

  @override
  void dispose() {
    _stopTimer();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final matchmakingControllerProvider =
    StateNotifierProvider<MatchmakingController, MatchmakingState>(
        (ref) => MatchmakingController(ref));
