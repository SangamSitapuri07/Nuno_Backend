import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Tracks whether the hosted backend is awake.
///
/// Render's free tier spins an instance down after ~15 minutes idle; the next
/// request then blocks for up to a minute while it cold-starts. Without a
/// signal for that, the UI just looks frozen. This pings `/health` on launch
/// and exposes the state so screens can show a "waking the server" hint.
enum ServerStatus { unknown, waking, awake, unreachable }

class ServerWakeupNotifier extends StateNotifier<ServerStatus> {
  ServerWakeupNotifier() : super(ServerStatus.unknown);

  Timer? _hintTimer;

  /// Pings the health endpoint. Safe to call repeatedly.
  Future<bool> ping() async {
    _hintTimer?.cancel();

    // Only claim we're "waking" if it is actually taking a while.
    _hintTimer = Timer(AppConfig.coldStartHintAfter, () {
      if (mounted && state != ServerStatus.awake) {
        state = ServerStatus.waking;
      }
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          validateStatus: (_) => true,
        ),
      );

      final res = await dio.get('${AppConfig.apiBaseUrl}/health');
      _hintTimer?.cancel();

      final ok = (res.statusCode ?? 500) >= 200 && (res.statusCode ?? 500) < 300;
      if (mounted) state = ok ? ServerStatus.awake : ServerStatus.unreachable;

      debugPrint('[health] ${res.statusCode} ${AppConfig.apiBaseUrl}/health');
      return ok;
    } catch (e) {
      _hintTimer?.cancel();
      debugPrint('[health] failed: $e');
      if (mounted) state = ServerStatus.unreachable;
      return false;
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }
}

final serverWakeupProvider =
    StateNotifierProvider<ServerWakeupNotifier, ServerStatus>(
        (ref) => ServerWakeupNotifier());
