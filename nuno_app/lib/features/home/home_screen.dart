import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/currency_pill.dart';
import '../../core/widgets/player_avatar.dart';
import '../auth/auth_controller.dart';
import 'home_providers.dart';

/// Screen 2 — home. Avatar + level on the left, currency and settings on the
/// right, one oversized PLAY button in the middle, bottom nav beneath.
class HomeScreen extends ConsumerWidget {
  /// Called when a bottom-nav destination other than Home is picked.
  final ValueChanged<int>? onNavigate;
  final int navIndex;

  const HomeScreen({super.key, this.onNavigate, this.navIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final unread = ref.watch(unreadBadgeProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.xl,
          vertical: AppDimens.md,
        ),
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────
            Row(
              children: [
                PlayerAvatar(
                  username: profile?.username ?? 'P',
                  avatarUrl: profile?.avatarUrl,
                  size: 38,
                  onTap: () => onNavigate?.call(4),
                ),
                const SizedBox(width: AppDimens.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile?.username ?? 'Player',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Lv. ${profile?.level ?? 1}',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                CurrencyPill(
                  coins: profile?.coins ?? 0,
                  onTap: () => onNavigate?.call(3),
                ),
                const SizedBox(width: AppDimens.sm),
                _CircleIcon(
                  icon: Icons.notifications_none_rounded,
                  badge: unread,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const SizedBox(width: AppDimens.sm),
                _CircleIcon(
                  icon: Icons.settings_rounded,
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),

            // ── PLAY ─────────────────────────────────
            const Expanded(child: Center(child: _PlayButton())),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton();

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.42).clamp(260.0, 420.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push(AppRoutes.playMenu);
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = 26 + _pulse.value * 20;
          return AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 110),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Card peeking out from behind the right edge, as in the
                // reference's home screen.
                Positioned(
                  right: -14,
                  child: Transform.rotate(
                    angle: 0.22,
                    child: Container(
                      width: 42,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B2E8F), Color(0xFF221A5C)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  width: width,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.xxl,
                    vertical: AppDimens.lg,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.playGradient,
                    borderRadius: AppDimens.brXl,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        blurRadius: glow,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ],
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppDimens.lg),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAY',
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white,
                    fontSize: 34,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Quick Match',
                  style: AppTextStyles.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _CircleIcon({required this.icon, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.surfaceStroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppDimens.brPill,
                border: Border.all(color: AppColors.background, width: 1.5),
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
    );
  }
}
