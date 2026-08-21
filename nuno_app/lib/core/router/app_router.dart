import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/game/game_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/play_menu_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/lobby/create_room_screen.dart';
import '../../features/lobby/join_room_screen.dart';
import '../../features/lobby/lobby_screen.dart';
import '../../features/matchmaking/matchmaking_screen.dart';
import '../../features/profile/achievements_screen.dart';
import '../../features/profile/match_history_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/tutorial_screen.dart';
import '../../features/store/daily_rewards_screen.dart';
import '../../features/auth/choose_username_screen.dart';
import '../../features/store/store_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';

  /// One-time setup after a first Google sign-in.
  static const chooseUsername = '/welcome/username';

  static const home = '/home';
  static const playMenu = '/play';
  static const createRoom = '/play/create';
  static const joinRoom = '/play/join';
  static const matchHistory = '/play/history';

  static const matchmaking = '/matchmaking';
  static const lobby = '/lobby';
  static const game = '/game';

  static const friends = '/friends';
  static const leaderboard = '/leaderboard';
  static const store = '/store';
  static const dailyRewards = '/store/daily';
  static const profile = '/profile';
  static const achievements = '/profile/achievements';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const tutorial = '/tutorial';
}

/// Rebuilds GoRouter's redirect whenever auth status flips.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AuthStatus>(
      authControllerProvider.select((s) => s.status),
      (_, __) => notifyListeners(),
    );

    // Also rebuilt when the username is claimed, which is what releases the
    // player from the setup screen.
    ref.listen<bool>(
      authControllerProvider.select((s) => s.needsUsername),
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

      if (auth.status == AuthStatus.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isAuthRoute = loc == AppRoutes.login;

      if (!auth.isLoggedIn) return isAuthRoute ? null : AppRoutes.login;

      // A signed-in account with no chosen name is pinned to the setup
      // screen. Enforced here rather than only at the call site, so it also
      // covers a cold start that restores a half-finished sign-up.
      if (auth.needsUsername) {
        return loc == AppRoutes.chooseUsername
            ? null
            : AppRoutes.chooseUsername;
      }

      // Conversely, once the name is set that screen is unreachable.
      if (isAuthRoute ||
          loc == AppRoutes.splash ||
          loc == AppRoutes.chooseUsername) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, s) => _fade(s, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.chooseUsername,
        pageBuilder: (_, s) => _fade(s, const ChooseUsernameScreen()),
      ),

      // ── Main shell ────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, s) => _fade(s, const HomeShell()),
      ),

      // ── Play flow ─────────────────────────────────
      GoRoute(
        path: AppRoutes.playMenu,
        pageBuilder: (_, s) => _slide(s, const PlayMenuScreen()),
      ),
      GoRoute(
        path: AppRoutes.createRoom,
        pageBuilder: (_, s) => _slide(s, const CreateRoomScreen()),
      ),
      GoRoute(
        path: AppRoutes.joinRoom,
        pageBuilder: (_, s) => _slide(s, const JoinRoomScreen()),
      ),
      GoRoute(
        path: AppRoutes.matchHistory,
        pageBuilder: (_, s) => _slide(s, const MatchHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.matchmaking,
        pageBuilder: (_, s) {
          final mode =
              s.extra is GameMode ? s.extra as GameMode : GameMode.casual;
          return _fade(s, MatchmakingScreen(mode: mode));
        },
      ),
      GoRoute(
        path: AppRoutes.lobby,
        pageBuilder: (_, s) => _slide(s, const LobbyScreen()),
      ),
      GoRoute(
        path: AppRoutes.game,
        pageBuilder: (_, s) => _fade(s, const GameScreen()),
      ),

      // ── Standalone destinations ───────────────────
      GoRoute(
        path: AppRoutes.friends,
        pageBuilder: (_, s) => _slide(s, const FriendsScreen()),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        pageBuilder: (_, s) => _slide(s, const LeaderboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.store,
        pageBuilder: (_, s) => _slide(s, const StoreScreen()),
      ),
      GoRoute(
        path: AppRoutes.dailyRewards,
        pageBuilder: (_, s) => _slide(s, const DailyRewardsScreen()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, s) => _slide(s, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        pageBuilder: (_, s) => _slide(s, const AchievementsScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, s) => _slide(s, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (_, s) => _slide(s, const NotificationsScreen()),
      ),
      GoRoute(
        path: AppRoutes.tutorial,
        pageBuilder: (_, s) => _slide(s, const TutorialScreen()),
      ),
    ],
  );
});

CustomTransitionPage _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    );

CustomTransitionPage _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, a, __, c) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0.03, 0), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: c),
        );
      },
    );
