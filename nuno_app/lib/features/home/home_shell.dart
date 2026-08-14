import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/socket_events.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../store/store_screen.dart';
import 'home_providers.dart';
import 'home_screen.dart';

/// Bottom-navigation shell (screen 2): Home · Friends · Leaderboard · Shop ·
/// Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _TabSpec(Icons.people_alt_rounded, Icons.people_alt_outlined, 'Friends'),
    _TabSpec(
        Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Leaderboard'),
    _TabSpec(Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, 'Shop'),
    _TabSpec(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
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
                const Icon(Icons.mail_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    '$from invited you to a room',
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'JOIN',
              textColor: AppColors.gold,
              onPressed: () {
                socket.emit(SocketEvents.inviteAccept, {'roomCode': roomCode});
                context.push(AppRoutes.lobby);
              },
            ),
          ),
        );
    });

    socket.on(SocketEvents.gameStarted).listen((_) {
      if (!mounted) return;
      if (GoRouterState.of(context).matchedLocation != AppRoutes.game) {
        context.push(AppRoutes.game);
      }
    });
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onNavigate: _go, navIndex: _index),
            const FriendsScreen(embedded: true),
            const LeaderboardScreen(embedded: true),
            const StoreScreen(embedded: true),
            const ProfileScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        tabs: _tabs,
        badges: {1: ref.watch(unreadBadgeProvider)},
        onChanged: _go,
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
  final Map<int, int> badges;

  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.onChanged,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.bottomNavHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.xxxl),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt.withValues(alpha: 0.97),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceStroke),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _Item(
                spec: tabs[i],
                isActive: i == index,
                badge: badges[i] ?? 0,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final _TabSpec spec;
  final bool isActive;
  final int badge;
  final VoidCallback onTap;

  const _Item({
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.lg,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: AppDimens.brPill,
                  ),
                  child: Icon(
                    isActive ? spec.active : spec.inactive,
                    size: 19,
                    color:
                        isActive ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: 6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: AppDimens.brPill,
                        border: Border.all(
                          color: AppColors.backgroundAlt,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              spec.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                color: isActive ? AppColors.primary : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
