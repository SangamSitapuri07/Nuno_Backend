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
    _TabSpec(Icons.home_rounded, Icons.home_rounded, 'HOME'),
    _TabSpec(Icons.emoji_events_rounded, Icons.emoji_events_rounded, 'RANK'),
    _TabSpec(Icons.shopping_cart_rounded, Icons.shopping_cart_rounded, 'SHOP'),
    _TabSpec(Icons.person_rounded, Icons.person_rounded, 'PROFILE'),
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
        decoration: const BoxDecoration(color: AppColors.background),
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onNavigate: _go, navIndex: _index),
            const LeaderboardScreen(embedded: true),
            const StoreScreen(embedded: true),
            const ProfileScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        tabs: _tabs,
        badges: const {},
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
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            width: 470,
            height: AppDimens.bottomNavHeight - 8,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            decoration: const BoxDecoration(
              color: Color(0xF00A0C22),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppDimens.radiusXxl),
              ),
            ),
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
                Icon(
                  isActive ? spec.active : spec.inactive,
                  size: 26,
                  color: isActive ? Colors.white : const Color(0xFF6E7396),
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
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                letterSpacing: 0.8,
                color: isActive ? Colors.white : const Color(0xFF6E7396),
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
