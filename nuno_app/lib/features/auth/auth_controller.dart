import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/google_auth_service.dart';
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

  /// True while a Google account still carries its generated placeholder
  /// name. The router sends these players to the username screen.
  bool get needsUsername =>
      status == AuthStatus.authenticated && profile?.usernameSet == false;

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

  /// Signs in with Google, creating the account on first use.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final idToken = await _ref.read(googleAuthServiceProvider).signIn();

      // Null means the player dismissed the account picker. That is not a
      // failure, so it must not leave an error on screen.
      if (idToken == null) {
        state = state.copyWith(isBusy: false);
        return false;
      }

      await _ref.read(authRepositoryProvider).googleSignIn(idToken);

      final profile = await _ref.read(userRepositoryProvider).getProfile();
      await _ref.read(tokenStorageProvider).saveUserId(profile.id);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
        isBusy: false,
      );

      await _ref.read(socketServiceProvider).connect();
      return true;
    } on GoogleSignInFailure catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        error: 'Google sign-in failed. Please try again.',
      );
      return false;
    }
  }

  /// Claims the player's chosen username after a Google sign-up.
  Future<bool> setUsername(String username) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref.read(authRepositoryProvider).setUsername(username.trim());

      // Re-read rather than patching locally: this is what flips
      // usernameSet, and the router keys off it.
      final profile = await _ref.read(userRepositoryProvider).getProfile();
      state = state.copyWith(profile: profile, isBusy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        error: 'Could not set your username. Please try again.',
      );
      return false;
    }
  }

  /// Live availability for the username field.
  Future<UsernameCheck> checkUsername(String username) =>
      _ref.read(authRepositoryProvider).checkUsername(username.trim());

  Future<void> logout() async {
    _ref.read(socketServiceProvider).disconnect();
    // Also drop the cached Google account, or the next sign-in silently
    // reuses it instead of showing the picker.
    await _ref.read(googleAuthServiceProvider).signOut();
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
