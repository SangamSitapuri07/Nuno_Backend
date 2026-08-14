import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/server_wakeup.dart';
import '../../core/providers.dart';
import '../../data/models/user_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  final AuthStatus status;
  final PlayerProfile? profile;
  final bool isBusy;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.profile,
    this.isBusy = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    PlayerProfile? profile,
    bool? isBusy,
    String? error,
    bool clearError = false,
    bool clearProfile = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );

  bool get isLoggedIn => status == AuthStatus.authenticated;
  String? get userId => profile?.id;
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  /// Restores a persisted session on cold start.
  Future<void> _bootstrap() async {
    // Wake the hosted backend first; on Render's free tier this can take
    // ~50s and would otherwise look like the app hanging.
    await _ref.read(serverWakeupProvider.notifier).ping();

    final auth = _ref.read(authRepositoryProvider);
    if (!await auth.hasSession()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final profile = await _ref.read(userRepositoryProvider).getProfile();
      await _ref.read(tokenStorageProvider).saveUserId(profile.id);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
      );
      await _ref.read(socketServiceProvider).connect();
    } catch (_) {
      await auth.logout();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearProfile: true,
      );
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).login(
            email: email.trim(),
            password: password,
          );
      final profile = await _ref.read(userRepositoryProvider).getProfile();
      await _ref.read(tokenStorageProvider).saveUserId(profile.id);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
        isBusy: false,
      );

      await _ref.read(socketServiceProvider).connect();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        error: 'Unable to sign in. Please try again.',
      );
      return false;
    }
  }

  /// Registers then immediately signs in (the backend register endpoint
  /// returns only a confirmation message).
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).register(
            username: username.trim(),
            email: email.trim(),
            password: password,
          );
      return login(email: email, password: password);
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        error: 'Unable to create your account. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    _ref.read(socketServiceProvider).disconnect();
    await _ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Refreshes the cached profile (coins, xp, level...).
  Future<void> refreshProfile() async {
    if (!state.isLoggedIn) return;
    try {
      final profile = await _ref.read(userRepositoryProvider).getProfile();
      state = state.copyWith(profile: profile);
    } catch (_) {
      // Keep the stale profile on failure.
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Called when the API layer reports the session is unrecoverable.
  void forceLogout() {
    _ref.read(socketServiceProvider).disconnect();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref);

  // React to hard session expiry surfaced by ApiClient.
  ref.listen<int>(sessionExpiredProvider, (previous, next) {
    if (previous != null && next > previous) controller.forceLogout();
  });

  return controller;
});

/// Convenience: the signed-in user's id.
final currentUserIdProvider =
    Provider<String?>((ref) => ref.watch(authControllerProvider).userId);

/// Convenience: the signed-in user's profile.
final currentProfileProvider = Provider<PlayerProfile?>(
    (ref) => ref.watch(authControllerProvider).profile);
