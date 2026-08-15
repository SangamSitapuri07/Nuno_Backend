import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import 'socket_events.dart';

enum SocketConnectionState { disconnected, connecting, connected, authenticated }

/// Single long-lived Socket.IO connection to the Nuno backend.
///
/// The backend expects an explicit `socket:authenticate` handshake carrying the
/// JWT after the transport connects (see src/websocket/socket.handler.ts), and
/// only registers gameplay handlers once that succeeds. This service reproduces
/// that lifecycle and re-authenticates automatically on every reconnect.
class SocketService {
  final TokenStorage _tokenStorage;

  io.Socket? _socket;

  final _stateController =
      StreamController<SocketConnectionState>.broadcast();

  /// Fires every time the socket (re)authenticates. Controllers listen to
  /// this to re-sync their state, because a dropped connection on a sleeping
  /// free-tier host loses all room membership on the server side.
  final _authedController = StreamController<void>.broadcast();
  final _errorController = StreamController<SocketError>.broadcast();

  /// event name -> broadcast controller of payload maps
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  SocketConnectionState _state = SocketConnectionState.disconnected;

  /// Called when the server rejects the handshake token. Wired to the REST
  /// client's refresh so an expired access token recovers without the user
  /// having to sign in again.
  Future<void> Function()? onAuthRejected;

  /// One refresh attempt per connection, reset once a handshake succeeds.
  bool _refreshAttempted = false;

  /// Consecutive transport-level connect failures, reset on a real connect.
  int _connectFailures = 0;
  String? _lastConnectError;

  /// Socket.IO reconnects on a 1s base delay, so this is a few seconds of
  /// failures — long enough to ride out a blip, short enough that a phone
  /// that simply cannot reach the host says so instead of spinning.
  static const int _failuresBeforeReporting = 4;

  /// Rolling record of what the transport actually did, shown in the lobby's
  /// diagnostics panel. Reading this off the screen is far easier than
  /// fishing `[socket]` lines out of a phone's logcat.
  final List<String> _trace = [];
  final _traceController = StreamController<List<String>>.broadcast();

  /// Most recent transport events, oldest first.
  List<String> get trace => List.unmodifiable(_trace);
  Stream<List<String>> get onTrace => _traceController.stream;

  void _trace_(String line) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _trace.add('$stamp  $line');
    if (_trace.length > 40) _trace.removeAt(0);
    debugPrint('[socket] $line');
    if (!_traceController.isClosed) _traceController.add(trace);
  }

  SocketService(this._tokenStorage);

  // ── Public surface ──────────────────────────────────────────

  SocketConnectionState get state => _state;
  Stream<SocketConnectionState> get onStateChanged => _stateController.stream;
  Stream<void> get onAuthenticated => _authedController.stream;
  Stream<SocketError> get onError => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _state == SocketConnectionState.authenticated;

  /// Typed stream of a socket event's payload.
  ///
  /// Safe to call before [connect]; the underlying listener is attached as soon
  /// as the socket exists. `_controllers` is the single source of truth for
  /// which events need binding.
  Stream<Map<String, dynamic>> on(String event) {
    final controller = _controllers.putIfAbsent(
      event,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );

    // If the socket already exists, attach now; otherwise connect() binds it.
    if (_socket != null) _bind(event);

    return controller.stream;
  }

  /// Event names currently attached to the live socket instance.
  final Set<String> _registered = {};

  /// Events emitted before authentication completes, replayed once it does.
  ///
  /// The backend registers its gameplay handlers only inside the
  /// `socket:authenticate` callback, so anything sent earlier is received by
  /// a socket that has no listener for it and is dropped without an error.
  /// That is what made "Create Room" and "Join" appear to do nothing on a
  /// cold start.
  final List<({String event, Map<String, dynamic> payload})> _pendingEmits = [];

  /// Events that are part of the handshake and must never be queued.
  static const _handshakeEvents = {SocketEvents.authenticate};

  void emit(String event, [Map<String, dynamic>? payload]) {
    final data = payload ?? <String, dynamic>{};

    if (_socket == null) {
      debugPrint('[socket] queued "$event" — no socket yet');
      _queue(event, data);
      connect();
      return;
    }

    if (!isAuthenticated && !_handshakeEvents.contains(event)) {
      debugPrint('[socket] queued "$event" — not authenticated yet');
      _queue(event, data);
      return;
    }

    debugPrint('[socket] → $event $data');
    _socket!.emit(event, data);
  }

  void _queue(String event, Map<String, dynamic> payload) {
    // Bound the buffer so a long outage cannot grow it without limit.
    if (_pendingEmits.length >= 32) _pendingEmits.removeAt(0);
    _pendingEmits.add((event: event, payload: payload));
  }

  /// Drops queued copies of [event] that a caller has given up waiting on.
  ///
  /// Without this a `room.create` that timed out on the client still fires the
  /// moment the handshake lands, creating a room nobody is watching. The next
  /// attempt then collides with it, which is what made "Create Room" fail
  /// permanently after one slow start.
  void cancelPending(String event) {
    _pendingEmits.removeWhere((e) => e.event == event);
  }

  void _flushPending() {
    if (_pendingEmits.isEmpty || _socket == null) return;
    final queued = List.of(_pendingEmits);
    _pendingEmits.clear();
    for (final e in queued) {
      debugPrint('[socket] → ${e.event} (replayed)');
      _socket!.emit(e.event, e.payload);
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      await _authenticate();
      return;
    }

    _trace_('connecting to ${AppConfig.socketUrl} ...');
    _setState(SocketConnectionState.connecting);

    // Replacing the socket instance invalidates all previous bindings.
    _socket?.dispose();
    _registered.clear();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          // Start on polling and let Socket.IO upgrade to websocket. Hosted
          // proxies (Render, Heroku, Cloudflare) frequently reject a direct
          // websocket handshake, which would strand a websocket-only client.
          .setTransports(['polling', 'websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1000)
          // A sleeping free-tier instance needs a long cold-start budget.
          .setReconnectionDelayMax(AppConfig.isRenderFreeTier ? 15000 : 5000)
          .setTimeout(AppConfig.connectTimeout.inMilliseconds)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) async {
        _trace_('transport connected to ${AppConfig.socketUrl}');
        _connectFailures = 0;
        _lastConnectError = null;
        _dispatch(SocketEvents.reachability, {'reachable': true});
        _setState(SocketConnectionState.connected);
        await _authenticate();
      })
      ..onDisconnect((reason) {
        _trace_('disconnected: $reason');
        _setState(SocketConnectionState.disconnected);
      })
      ..onConnectError((e) {
        _trace_('connect_error: $e');
        _setState(SocketConnectionState.disconnected);

        // Socket.IO retries silently forever. Left alone that is
        // indistinguishable from a slow server, so the caller sits on a
        // spinner with no idea the transport is failing. Report it once the
        // retries stop looking like an ordinary cold start.
        _connectFailures++;
        _lastConnectError = e?.toString();
        if (_connectFailures == _failuresBeforeReporting) {
          _dispatch(SocketEvents.reachability, {
            'reachable': false,
            'attempts': _connectFailures,
            'detail': _lastConnectError ?? 'connection refused',
          });
        }
      })
      ..onError((e) => _trace_('transport error: $e'));

    // Auth ack from the server.
    _socket!.on(SocketEvents.authenticated, (data) {
      _trace_('handshake accepted (authenticated)');
      _authTimeout?.cancel();
      _authTimeout = null;
      _refreshAttempted = false;
      _setState(SocketConnectionState.authenticated);
      _dispatch(SocketEvents.authenticated, data);
      _flushPending();
      if (!_authedController.isClosed) _authedController.add(null);
    });

    // Server-side errors: { code, message }
    _socket!.on(SocketEvents.error, (data) {
      final map = _asMap(data);
      final err = SocketError(
        code: (map['code'] ?? 'SERVER_ERROR').toString(),
        message: (map['message'] ?? 'Something went wrong.').toString(),
      );
      _trace_('server error ${err.code}: ${err.message}');

      // A rejected handshake leaves emits queued behind `isAuthenticated`
      // with nothing left to release them, so treat it as a hard failure
      // rather than a passing error the caller may ignore.
      if (err.code == 'TOKEN_EXPIRED' || err.code == 'AUTH_FAILED') {
        _authTimeout?.cancel();
        _authTimeout = null;
        _pendingEmits.clear();

        // Renewing re-runs the handshake, so a token the server keeps
        // refusing would otherwise loop. One attempt per connection is
        // enough: a second rejection means the session is genuinely dead.
        if (!_refreshAttempted && onAuthRejected != null) {
          _refreshAttempted = true;
          onAuthRejected!();
        }
      }

      _errorController.add(err);
      _dispatch(SocketEvents.error, data);
    });

    // Bind every stream requested before the socket existed.
    for (final event in _controllers.keys.toList()) {
      _bind(event);
    }

    _socket!.connect();
  }

  /// Guards against a handshake that is accepted at the transport level but
  /// never acknowledged, which would otherwise leave queued emits parked
  /// forever behind `isAuthenticated`.
  Timer? _authTimeout;

  Future<void> _authenticate() async {
    final token = await _tokenStorage.readAccessToken();

    if (token == null || token.isEmpty) {
      // Surfacing this matters: every gameplay emit is queued until the
      // handshake lands, so a silent return strands the caller on its
      // loading state with nothing to react to.
      _trace_('no access token stored - cannot authenticate');
      _failHandshake(
        'AUTH_REQUIRED',
        'Your session has expired. Please sign in again.',
      );
      return;
    }

    _authTimeout?.cancel();
    _authTimeout = Timer(AppConfig.connectTimeout, () {
      if (isAuthenticated) return;
      _trace_('handshake timed out after ${AppConfig.connectTimeout.inSeconds}s');
      _failHandshake(
        'AUTH_TIMEOUT',
        'Could not reach the server. Check your connection and try again.',
      );
    });

    _trace_('sending handshake (socket:authenticate)');
    _socket?.emit(SocketEvents.authenticate, {'token': token});
  }

  /// Drops anything waiting on the handshake and tells listeners why, so a
  /// screen blocked on a queued emit can stop waiting.
  void _failHandshake(String code, String message) {
    _authTimeout?.cancel();
    _authTimeout = null;
    _pendingEmits.clear();
    if (!_errorController.isClosed) {
      _errorController.add(SocketError(code: code, message: message));
    }
    _dispatch(SocketEvents.error, {'code': code, 'message': message});
  }

  /// Re-authenticate after a token refresh.
  Future<void> reauthenticate() => _authenticate();

  void disconnect() {
    _authTimeout?.cancel();
    _authTimeout = null;
    _socket?.dispose();
    _socket = null;
    _registered.clear();
    _setState(SocketConnectionState.disconnected);
  }

  Future<void> dispose() async {
    disconnect();
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
    await _traceController.close();
    await _authedController.close();
    await _stateController.close();
    await _errorController.close();
  }

  // ── Internals ───────────────────────────────────────────────

  void _bind(String event) {
    if (_socket == null || _registered.contains(event)) return;
    if (event == SocketEvents.error ||
        event == SocketEvents.authenticated) {
      // Already bound explicitly above.
      _registered.add(event);
      return;
    }
    _registered.add(event);
    _socket!.on(event, (data) {
      debugPrint('[socket] ← $event');
      _dispatch(event, data);
    });
  }

  void _dispatch(String event, dynamic data) {
    final controller = _controllers[event];
    if (controller == null || controller.isClosed) return;
    controller.add(_asMap(data));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return {'value': data};
  }

  void _setState(SocketConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}

class SocketError {
  final String code;
  final String message;

  const SocketError({required this.code, required this.message});

  @override
  String toString() => message;
}
