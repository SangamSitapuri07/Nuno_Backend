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
import '../auth/auth_controller.dart';
import 'widgets/friends_panel.dart';
import 'widgets/player_badge.dart';

/// Home screen — galaxy backdrop with a card podium, daily-gift chest, an
/// ornate gold PLAY button and a docked friends panel.
///
/// Everything is laid out proportionally from the real canvas size, because
/// phone aspect ratios in landscape vary hugely (2.0 to 2.4+) and fixed
/// offsets caused the podium to collide with the header.
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

        // Darken top and bottom so the HUD stays readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB305030F), Color(0x1A05030F), Color(0xB305030F)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;

              // Reserve columns so nothing overlaps:
              //   left   header badge
              //   right  friends panel, and the PLAY button beneath it
              final panelWidth = (w * 0.30).clamp(230.0, 330.0);
              final headerHeight = (h * 0.20).clamp(52.0, 78.0);

              // The bottom nav floats over the left of the screen.
              const navHeight = 60.0;

              // Stage = the area left of the friends panel, below the header
              // and above the floating nav bar.
              final stageWidth = w - panelWidth - AppDimens.xl;
              final stageHeight = h - headerHeight - navHeight;

              // Podium is the hero; size it off the smaller constraint.
              final podiumWidth =
                  (stageWidth * 0.46).clamp(150.0, stageHeight * 1.15);
              final chestWidth = (podiumWidth * 0.42).clamp(70.0, 130.0);
              final playWidth = (panelWidth * 0.62).clamp(110.0, 190.0);

              return Stack(
                children: [
                  // ── Header: badge + currency ───────
                  Positioned(
                    top: AppDimens.sm,
                    left: AppDimens.lg,
                    right: panelWidth + AppDimens.xl,
                    child: _Header(
                      profile: profile,
                      onProfile: () => onNavigate?.call(3),
                      onShop: () => onNavigate?.call(2),
                      onSettings: () => context.push(AppRoutes.settings),
                    ),
                  ),

                  // ── Podium, centred in the stage ───
                  Positioned(
                    left: 0,
                    right: panelWidth + AppDimens.xl,
                    top: headerHeight,
                    bottom: navHeight,
                    child: Align(
                      alignment: const Alignment(-0.30, 0.35),
                      child: _FloatingAsset(
                        asset: Art.cardPodium,
                        width: podiumWidth,
                        onTap: () => context.push(AppRoutes.playMenu),
                      ),
                    ),
                  ),

                  // ── Daily gift chest ───────────────
                  Positioned(
                    left: 0,
                    right: panelWidth + AppDimens.xl,
                    top: headerHeight,
                    bottom: navHeight,
                    child: Align(
                      alignment: const Alignment(0.88, 0.10),
                      child: _FloatingAsset(
                        asset: Art.treasureChest,
                        width: chestWidth,
                        amplitude: 5,
                        onTap: () => context.push(AppRoutes.dailyRewards),
                      ),
                    ),
                  ),

                  // ── Friends panel, docked right ────
                  Positioned(
                    top: AppDimens.sm,
                    right: AppDimens.lg,
                    width: panelWidth,
                    // Leave room for PLAY underneath.
                    height: h * 0.52,
                    child: const FriendsPanel(),
                  ),

                  // ── PLAY, below the friends panel ──
                  Positioned(
                    right: AppDimens.lg,
                    bottom: AppDimens.sm,
                    width: panelWidth,
                    child: Align(
                      alignment: Alignment.center,
                      child: _PlayButton(
                        width: playWidth,
                        onTap: () => context.push(AppRoutes.playMenu),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header row ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final dynamic profile;
  final VoidCallback onProfile;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  const _Header({
    required this.profile,
    required this.onProfile,
    required this.onShop,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: PlayerBadge(
            username: profile?.username ?? 'Player',
            avatarUrl: profile?.avatarUrl,
            level: profile?.level ?? 1,
            levelProgress: profile?.levelProgress ?? 0,
            tier: profile?.leaderboard?.tier ?? RankTier.bronze,
            onTap: onProfile,
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        _CurrencyCapsule(
          icon: Icons.monetization_on_rounded,
          iconColor: AppColors.gold,
          value: profile?.coins ?? 0,
          onAdd: onShop,
        ),
        const SizedBox(width: AppDimens.sm),
        _CurrencyCapsule(
          icon: Icons.diamond_rounded,
          iconColor: AppColors.cyan,
          // The backend has no gem currency yet.
          value: 0,
          onAdd: onShop,
        ),
        const SizedBox(width: AppDimens.sm),
        _GlassCircleButton(icon: Icons.settings_rounded, onTap: onSettings),
      ],
    );
  }
}

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
      height: 36,
      padding: const EdgeInsets.only(left: 5, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6121430),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 6),
          Text(
            Formatters.compact(value),
            style: AppTextStyles.h4.copyWith(fontSize: 15),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add_rounded, size: 13, color: Colors.white),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xE6121430),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, size: 19, color: Colors.white70),
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
  final double width;

  const _PlayButton({required this.onTap, this.width = 170});

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
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold
                      .withValues(alpha: 0.28 + 0.20 * _pulse.value),
                  blurRadius: 26 + 14 * _pulse.value,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
          child: Transform.rotate(
            angle: -0.03,
            child: Image.asset(
              Art.btnPlay,
              width: widget.width,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: widget.width,
                height: widget.width * 0.5,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(18),
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
