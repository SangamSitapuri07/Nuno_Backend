import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/game_assets.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../auth/auth_controller.dart';
import 'widgets/friends_panel.dart';
import 'widgets/player_badge.dart';

/// Home screen — galaxy backdrop with a card podium, daily-gift chest, an
/// ornate gold PLAY button and a docked friends panel.
class HomeScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigate;
  final int navIndex;

  const HomeScreen({super.key, this.onNavigate, this.navIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Galaxy backdrop ──────────────────────────
        Image.asset(
          Art.bgGalaxy,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
        ),

        // Darken the corners so the HUD stays readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.15, -0.1),
              radius: 1.1,
              colors: [Colors.transparent, Color(0xCC05030F)],
              stops: [0.45, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: Stack(
            children: [
              // ── Top-left: player badge ─────────────
              Positioned(
                top: AppDimens.md,
                left: AppDimens.lg,
                child: PlayerBadge(
                  username: profile?.username ?? 'Player',
                  avatarUrl: profile?.avatarUrl,
                  level: profile?.level ?? 1,
                  levelProgress: profile?.levelProgress ?? 0,
                  tier: profile?.leaderboard?.tier ?? RankTier.bronze,
                  onTap: () => onNavigate?.call(3),
                ),
              ),

              // ── Currency + settings ────────────────
              Positioned(
                top: AppDimens.md + 6,
                left: 300,
                child: Row(
                  children: [
                    _CurrencyCapsule(
                      icon: Icons.monetization_on_rounded,
                      iconColor: AppColors.gold,
                      value: profile?.coins ?? 0,
                      onAdd: () => onNavigate?.call(2),
                    ),
                    const SizedBox(width: AppDimens.md),
                    _CurrencyCapsule(
                      icon: Icons.diamond_rounded,
                      iconColor: AppColors.cyan,
                      // The backend has no gem currency yet.
                      value: 0,
                      onAdd: () => onNavigate?.call(2),
                    ),
                    const SizedBox(width: AppDimens.md),
                    _GlassCircleButton(
                      icon: Icons.settings_rounded,
                      onTap: () => context.push(AppRoutes.settings),
                    ),
                  ],
                ),
              ),

              // ── Card podium, left of centre ────────
              Align(
                alignment: const Alignment(-0.52, 0.16),
                child: _FloatingAsset(
                  asset: Art.cardPodium,
                  width: 380,
                  onTap: () => context.push(AppRoutes.playMenu),
                ),
              ),

              // ── Daily gift chest ───────────────────
              Align(
                alignment: const Alignment(0.18, 0.16),
                child: _FloatingAsset(
                  asset: Art.treasureChest,
                  width: 170,
                  amplitude: 5,
                  onTap: () => context.push(AppRoutes.dailyRewards),
                ),
              ),

              // ── Ornate gold PLAY ───────────────────
              Align(
                alignment: const Alignment(0.72, 0.52),
                child: _PlayButton(
                  onTap: () => context.push(AppRoutes.playMenu),
                ),
              ),

              // ── Friends panel, docked right ────────
              const Positioned(
                top: AppDimens.sm,
                right: AppDimens.lg,
                child: FriendsPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Currency capsule with a "+" button ────────────────────────

class _CurrencyCapsule extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final VoidCallback onAdd;

  const _CurrencyCapsule({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 6, right: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6121430),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(
            Formatters.compact(value),
            style: AppTextStyles.h4.copyWith(fontSize: 17),
          ),
          const SizedBox(width: AppDimens.sm),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            ),
          ),
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xE6121430),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, size: 21, color: Colors.white70),
      ),
    );
  }
}

// ── Gently bobbing image asset ────────────────────────────────

class _FloatingAsset extends StatefulWidget {
  final String asset;
  final double width;
  final double amplitude;
  final VoidCallback? onTap;

  const _FloatingAsset({
    required this.asset,
    required this.width,
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
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -widget.amplitude * _c.value),
          child: child,
        ),
        child: Image.asset(
          widget.asset,
          width: widget.width,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => SizedBox(width: widget.width),
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
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold
                      .withValues(alpha: 0.30 + 0.22 * _pulse.value),
                  blurRadius: 30 + 18 * _pulse.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: Transform.rotate(
            angle: -0.04,
            child: Image.asset(
              Art.btnPlay,
              width: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 190,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PLAY',
                  style: AppTextStyles.h1.copyWith(
                    color: const Color(0xFF3A2600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
