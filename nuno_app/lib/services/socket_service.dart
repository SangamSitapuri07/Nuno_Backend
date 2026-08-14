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
  final _errorController = StreamController<SocketError>.broadcast();

  /// event name -> broadcast controller of payload maps
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  SocketConnectionState _state = SocketConnectionState.disconnected;

  SocketService(this._tokenStorage);

  // ── Public surface ──────────────────────────────────────────

  SocketConnectionState get state => _state;
  Stream<SocketConnectionState> get onStateChanged => _stateController.stream;
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

  void emit(String event, [Map<String, dynamic>? payload]) {
    if (_socket == null) {
      debugPrint('[socket] dropped "$event" — not connected');
      return;
    }
    debugPrint('[socket] → $event ${payload ?? ''}');
    _socket!.emit(event, payload ?? <String, dynamic>{});
  }

  // ── Lifecycle ───────────────────────────────────────────────

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      await _authenticate();
      return;
    }

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
        debugPrint('[socket] connected');
        _setState(SocketConnectionState.connected);
        await _authenticate();
      })
      ..onDisconnect((reason) {
        debugPrint('[socket] disconnected: $reason');
        _setState(SocketConnectionState.disconnected);
      })
      ..onConnectError((e) {
        debugPrint('[socket] connect_error: $e');
        _setState(SocketConnectionState.disconnected);
      })
      ..onError((e) => debugPrint('[socket] error: $e'));

    // Auth ack from the server.
    _socket!.on(SocketEvents.authenticated, (data) {
      debugPrint('[socket] authenticated');
      _setState(SocketConnectionState.authenticated);
      _dispatch(SocketEvents.authenticated, data);
    });

    // Server-side errors: { code, message }
    _socket!.on(SocketEvents.error, (data) {
      final map = _asMap(data);
      final err = SocketError(
        code: (map['code'] ?? 'SERVER_ERROR').toString(),
        message: (map['message'] ?? 'Something went wrong.').toString(),
      );
      debugPrint('[socket] ← error ${err.code}: ${err.message}');
      _errorController.add(err);
      _dispatch(SocketEvents.error, data);
    });

    // Bind every stream requested before the socket existed.
    for (final event in _controllers.keys.toList()) {
      _bind(event);
    }

    _socket!.connect();
  }

  Future<void> _authenticate() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[socket] no token — skipping authenticate');
      return;
    }
    _socket?.emit(SocketEvents.authenticate, {'token': token});
  }

  /// Re-authenticate after a token refresh.
  Future<void> reauthenticate() => _authenticate();

  void disconnect() {
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
