import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/game/game_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/lobby/lobby_screen.dart';
import '../../features/matchmaking/matchmaking_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/store/store_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const matchmaking = '/matchmaking';
  static const lobby = '/lobby';
  static const game = '/game';
  static const friends = '/friends';
  static const leaderboard = '/leaderboard';
  static const store = '/store';
  static const profile = '/profile';
  static const settings = '/settings';
}

/// Rebuilds GoRouter's redirect whenever auth status flips.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AuthStatus>(
      authControllerProvider.select((s) => s.status),
      (_, __) => notifyListeners(),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      // Hold on the splash until the session is resolved.
      if (auth.status == AuthStatus.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isAuthRoute =
          loc == AppRoutes.login || loc == AppRoutes.register;

      if (!auth.isLoggedIn) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // Signed in: keep them out of splash/auth screens.
      if (isAuthRoute || loc == AppRoutes.splash) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) =>
            _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (_, state) =>
            _slide(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, state) => _fade(state, const HomeShell()),
      ),
      GoRoute(
        path: AppRoutes.matchmaking,
        pageBuilder: (_, state) {
          final mode = state.extra is GameMode
              ? state.extra as GameMode
              : GameMode.casual;
          return _fade(state, MatchmakingScreen(mode: mode));
        },
      ),
      GoRoute(
        path: AppRoutes.lobby,
        pageBuilder: (_, state) => _slide(state, const LobbyScreen()),
      ),
      GoRoute(
        path: AppRoutes.game,
        pageBuilder: (_, state) => _fade(state, const GameScreen()),
      ),
      GoRoute(
        path: AppRoutes.friends,
        pageBuilder: (_, state) => _slide(state, const FriendsScreen()),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        pageBuilder: (_, state) => _slide(state, const LeaderboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.store,
        pageBuilder: (_, state) => _slide(state, const StoreScreen()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, state) => _slide(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, state) => _slide(state, const SettingsScreen()),
      ),
    ],
  );
});

CustomTransitionPage _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

CustomTransitionPage _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
