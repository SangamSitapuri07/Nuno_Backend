import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../services/socket_events.dart';
import '../../core/providers.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../store/store_screen.dart';
import 'home_providers.dart';
import 'home_screen.dart';

/// Bottom-navigation shell hosting the five main tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _TabSpec(Icons.leaderboard_rounded, Icons.leaderboard_outlined, 'Ranks'),
    _TabSpec(Icons.storefront_rounded, Icons.storefront_outlined, 'Store'),
    _TabSpec(Icons.people_alt_rounded, Icons.people_alt_outlined, 'Friends'),
    _TabSpec(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    // Connect the socket and start listening for global invites.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketBootstrapProvider);
      _listenForInvites();
    });
  }

  void _listenForInvites() {
    final socket = ref.read(socketServiceProvider);

    socket.on(SocketEvents.inviteReceived).listen((payload) {
      if (!mounted) return;
      final from = payload['fromUsername']?.toString() ?? 'A friend';
      final roomCode = payload['roomCode']?.toString();
      if (roomCode == null) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Row(
              children: [
                const Icon(Icons.mail_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    '$from invited you to a room',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'JOIN',
              textColor: AppColors.accent,
              onPressed: () {
                socket.emit(SocketEvents.inviteAccept, {'roomCode': roomCode});
                context.push(AppRoutes.lobby);
              },
            ),
          ),
        );
    });

    // The host started the game (or matchmaking auto-started it).
    socket.on(SocketEvents.gameStarted).listen((_) {
      if (!mounted) return;
      final location = GoRouterState.of(context).matchedLocation;
      if (location != AppRoutes.game) context.push(AppRoutes.game);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AppBackground(
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            LeaderboardScreen(embedded: true),
            StoreScreen(embedded: true),
            FriendsScreen(embedded: true),
            ProfileScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        tabs: _tabs,
        badgeForIndex: {3: ref.watch(unreadBadgeProvider)},
        onChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _TabSpec {
  final IconData active;
  final IconData inactive;
  final String label;

  const _TabSpec(this.active, this.inactive, this.label);
}

class _BottomBar extends StatelessWidget {
  final int index;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onChanged;
  final Map<int, int> badgeForIndex;

  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.onChanged,
    this.badgeForIndex = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom > 0
            ? MediaQuery.paddingOf(context).bottom - 4
            : AppDimens.sm,
        top: AppDimens.sm,
        left: AppDimens.md,
        right: AppDimens.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt.withValues(alpha: 0.97),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceStroke),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _BottomBarItem(
              spec: tabs[i],
              isActive: i == index,
              badge: badgeForIndex[i] ?? 0,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final _TabSpec spec;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.spec,
    required this.isActive,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: AppDimens.brPill,
                    ),
                    child: Icon(
                      isActive ? spec.active : spec.inactive,
                      size: 22,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: 8,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: AppDimens.brPill,
                          border: Border.all(
                            color: AppColors.backgroundAlt,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
