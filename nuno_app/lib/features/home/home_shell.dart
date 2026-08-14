import 'dart:async';

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

  /// The nav bar hides itself after a few idle seconds, the way most mobile
  /// games do, and reappears on any tap.
  bool _navVisible = true;
  Timer? _hideTimer;

  static const _idleBeforeHide = Duration(seconds: 4);

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_idleBeforeHide, () {
      if (mounted) setState(() => _navVisible = false);
    });
  }

  void _revealNav() {
    if (!_navVisible) setState(() => _navVisible = true);
    _scheduleHide();
  }

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
      _scheduleHide();
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
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Listener(
        // Any touch reveals the bar and restarts the idle countdown.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _revealNav(),
        child: DecoratedBox(
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
      ),
      // Slides out of view when idle instead of occupying layout space.
      // While hidden it also ignores pointers, so the Listener above (and
      // the handle drawn inside _BottomBar) is what brings it back.
      bottomNavigationBar: IgnorePointer(
        ignoring: !_navVisible,
        child: AnimatedSlide(
          offset: _navVisible ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _navVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: _BottomBar(
              index: _index,
              tabs: _tabs,
              badges: const {},
              onChanged: _go,
            ),
          ),
        ),
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
            width: 380,
            height: 54,
            margin: const EdgeInsets.only(left: AppDimens.md, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            decoration: BoxDecoration(
              color: const Color(0xE60A0C22),
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  size: 22,
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
            const SizedBox(height: 2),
            Text(
              spec.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                letterSpacing: 0.6,
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
