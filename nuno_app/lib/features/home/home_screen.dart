import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_models.dart';
import '../auth/auth_controller.dart';
import 'widgets/friends_panel.dart';
import 'widgets/player_badge.dart';

/// Home screen.
///
/// Laid out with Column/Row slots rather than a Stack of Positioned widgets.
/// Every element owns a real box, and each image is wrapped so it scales to
/// fit its box — so nothing can overflow into a neighbour regardless of the
/// device aspect ratio.
///
///   ┌──────────────────────────────────────────────┐
///   │ header: badge · coins · gems · settings      │  fixed height
///   ├───────────────────────────────┬──────────────┤
///   │ stage: podium │ chest         │ friends      │  flexible
///   │                               ├──────────────┤
///   │                               │ PLAY         │
///   ├───────────────────────────────┴──────────────┤
///   │ (space reserved for the floating nav bar)    │
///   └──────────────────────────────────────────────┘
class HomeScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigate;
  final int navIndex;

  const HomeScreen({super.key, this.onNavigate, this.navIndex = 0});

  /// Height reserved at the bottom for the shell's floating nav bar.
  static const double navReserve = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          Art.bgGalaxy,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB805030F), Color(0x1405030F), Color(0xB805030F)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;

              // Right column: friends panel above, PLAY below.
              final panelWidth = (w * 0.29).clamp(200.0, 320.0);
              // Header shrinks on short canvases so the stage keeps room.
              final headerHeight = (h * 0.19).clamp(46.0, 66.0);
              // PLAY is pinned bottom-right; the panel takes the rest.
              final playHeight = (h * 0.28).clamp(70.0, 120.0);

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.md,
                  AppDimens.sm,
                  AppDimens.md,
                  0,
                ),
                // Two full-height columns. The header lives inside the LEFT
                // column only, so the friends panel on the right can start at
                // the very top of the screen.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left column: header over the stage ──
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: Row(
                              children: [
                                Flexible(
                                  child: PlayerBadge(
                                    username: profile?.username ?? 'Player',
                                    avatarUrl: profile?.avatarUrl,
                                    level: profile?.level ?? 1,
                                    levelProgress: profile?.levelProgress ?? 0,
                                    tier: profile?.leaderboard?.tier ??
                                        RankTier.bronze,
                                    onTap: () => onNavigate?.call(3),
                                  ),
                                ),
                                const SizedBox(width: AppDimens.sm),
                                _CurrencyCapsule(
                                  icon: Icons.monetization_on_rounded,
                                  iconColor: AppColors.gold,
                                  value: profile?.coins ?? 0,
                                  onAdd: () => onNavigate?.call(2),
                                ),
                                const SizedBox(width: 6),
                                const _CurrencyCapsule(
                                  icon: Icons.diamond_rounded,
                                  iconColor: AppColors.cyan,
                                  // No gem currency on the backend yet.
                                  value: 0,
                                ),
                                const SizedBox(width: 6),
                                _GlassCircleButton(
                                  icon: Icons.settings_rounded,
                                  onTap: () =>
                                      context.push(AppRoutes.settings),
                                ),
                              ],
                            ),
                          ),

                          // Stage: podium + chest.
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppDimens.sm,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _FloatingAsset(
                                      asset: Art.cardPodium,
                                      onTap: () =>
                                          context.push(AppRoutes.playMenu),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 52,
                                      ),
                                      child: _FloatingAsset(
                                        asset: Art.treasureChest,
                                        amplitude: 5,
                                        onTap: () => context
                                            .push(AppRoutes.dailyRewards),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Partial clearance for the floating nav bar. The
                          // bar is only 380 wide and docked bottom-left, and
                          // the podium art tapers at its base, so the stage
                          // may reach into part of that band - which keeps the
                          // podium box tall, so it renders large and low.
                          const SizedBox(height: navReserve - 28),
                        ],
                      ),
                    ),

                    // ── Right column: friends from the very top,
                    //    PLAY pinned at the bottom ──
                    SizedBox(
                      width: panelWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: const FriendsPanel(),
                          ),
                          SizedBox(
                            height: playHeight,
                            child: _PlayButton(
                              onTap: () => context.push(AppRoutes.playMenu),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Currency capsule ──────────────────────────────────────────

class _CurrencyCapsule extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final VoidCallback? onAdd;

  const _CurrencyCapsule({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6121430),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 5),
          Text(
            Formatters.compact(value),
            style: AppTextStyles.h4.copyWith(fontSize: 14),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ] else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xE6121430),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, size: 18, color: Colors.white70),
      ),
    );
  }
}

// ── Bobbing asset that always fits its slot ───────────────────

class _FloatingAsset extends StatefulWidget {
  final String asset;
  final double amplitude;
  final VoidCallback? onTap;

  const _FloatingAsset({
    required this.asset,
    this.amplitude = 7,
    this.onTap,
  });

  @override
  State<_FloatingAsset> createState() => _FloatingAssetState();
}

class _FloatingAssetState extends State<_FloatingAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -widget.amplitude * _c.value),
          child: child,
        ),
        // BoxFit.contain guarantees the art never exceeds its slot.
        child: Image.asset(
          widget.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ── Ornate gold PLAY button ───────────────────────────────────

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold
                      .withValues(alpha: 0.26 + 0.20 * _pulse.value),
                  blurRadius: 22 + 12 * _pulse.value,
                ),
              ],
            ),
            child: child,
          ),
          child: Image.asset(
            Art.btnPlay,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'PLAY',
                style: AppTextStyles.h2.copyWith(
                  color: const Color(0xFF3A2600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
