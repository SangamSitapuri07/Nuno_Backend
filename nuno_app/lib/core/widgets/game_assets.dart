import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Central registry of the generated image assets.
///
/// Keeping the paths in one place means a missing or renamed file surfaces in
/// exactly one spot rather than scattered across screens.
class Art {
  Art._();

  static const bgGalaxy = 'assets/images/bg_galaxy.jpg';
  static const bgTable = 'assets/images/bg_table.jpg';

  static const cardPodium = 'assets/images/card_podium.png';
  static const cardBack3d = 'assets/images/card_back_3d.png';
  static const treasureChest = 'assets/images/treasure_chest.png';
  static const shopBundle = 'assets/images/shop_bundle.png';

  static const trophy = 'assets/images/trophy_gold.png';
  static const coinStack = 'assets/images/coin_stack.png';
  static const gemStack = 'assets/images/gem_stack.png';

  static const unoBurst = 'assets/images/uno_burst.png';
  static const victoryBanner = 'assets/images/victory_banner.png';
  static const panelFrame = 'assets/images/panel_frame.png';

  static const btnPlay = 'assets/images/btn_play_gold.png';
  static const btnStart = 'assets/images/btn_start.png';
  static const btnJoin = 'assets/images/btn_join.png';
  static const btnReady = 'assets/images/btn_ready.png';
  static const btnInvite = 'assets/images/btn_invite.png';
}

/// Full-bleed background image with a graceful gradient fallback.
class ArtBackground extends StatelessWidget {
  final String asset;
  final Widget child;

  /// Darkens the edges so overlaid UI stays legible.
  final bool vignette;

  const ArtBackground({
    super.key,
    required this.asset,
    required this.child,
    this.vignette = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
        ),
        if (vignette)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.05,
                colors: [Colors.transparent, Color(0xCC05030F)],
                stops: [0.42, 1.0],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// An image asset that degrades to [fallback] if the file is missing.
class ArtImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final Widget? fallback;
  final BoxFit fit;

  const ArtImage(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fallback,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          fallback ?? SizedBox(width: width, height: height),
    );
  }
}

/// Ornate gold-framed dialog panel built from `panel_frame.png`, with the
/// content inset to sit inside the border.
class OrnatePanel extends StatelessWidget {
  final String? title;
  final Widget child;
  final double width;
  final VoidCallback? onClose;

  const OrnatePanel({
    super.key,
    required this.child,
    this.title,
    this.width = 640,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              Art.panelFrame,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppDimens.brXl,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
              ),
            ),
          ),

          // Inset so content clears the decorative border.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.075,
              vertical: width * 0.055,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!.toUpperCase(),
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 1.6,
                      shadows: [
                        const Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                ],
                Flexible(child: child),
              ],
            ),
          ),

          if (onClose != null)
            Positioned(
              top: 2,
              right: 6,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.4),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: AppColors.gold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tappable gold button backed by one of the generated button images.
class ArtButton extends StatefulWidget {
  final String asset;
  final double width;
  final VoidCallback? onTap;

  /// Rendered when the asset is unavailable.
  final String fallbackLabel;

  const ArtButton({
    super.key,
    required this.asset,
    required this.fallbackLabel,
    this.width = 170,
    this.onTap,
  });

  @override
  State<ArtButton> createState() => _ArtButtonState();
}

class _ArtButtonState extends State<ArtButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Image.asset(
            widget.asset,
            width: widget.width,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: widget.width,
              height: widget.width * 0.34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: AppDimens.brMd,
              ),
              child: Text(
                widget.fallbackLabel,
                style: AppTextStyles.button.copyWith(
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
