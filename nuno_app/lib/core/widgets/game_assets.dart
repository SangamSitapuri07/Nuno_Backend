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

  static const bgPanel = 'assets/images/bg_panel.jpg';
  static const bgStore = 'assets/images/bg_store.jpg';

  static const appIcon = 'assets/images/app_icon.png';

  // Collectible card-back skins sold in the store.
  static const skinClassic = 'assets/images/skin_classic.png';
  static const skinNeon = 'assets/images/skin_neon.png';
  static const skinGold = 'assets/images/skin_gold.png';
  static const skinDiamond = 'assets/images/skin_diamond.png';
  static const skinFire = 'assets/images/skin_fire.png';
  static const skinOcean = 'assets/images/skin_ocean.png';

  // Purchasable avatar portraits. The default remains the initials tile.
  static const avatarWarrior = 'assets/images/avatar_warrior.png';
  static const avatarWizard = 'assets/images/avatar_wizard.png';
  static const avatarRogue = 'assets/images/avatar_rogue.png';
  static const avatarQueen = 'assets/images/avatar_queen.png';

  // Table themes sold in the store. These are the store thumbnails; the
  // in-game background uses the full-bleed bg_* images.
  static const tableGalaxy = 'assets/images/table_galaxy.png';
  static const tableMidnight = 'assets/images/table_midnight.png';
  static const tableAurora = 'assets/images/table_aurora.png';

  // Achievement medals.
  static const medalStar = 'assets/images/medal_star.png';
  static const medalCards = 'assets/images/medal_cards.png';
  static const medalFirst = 'assets/images/medal_first.png';
  static const medalFlame = 'assets/images/medal_flame.png';
  static const medalBolt = 'assets/images/medal_bolt.png';
  static const medalCrown = 'assets/images/medal_crown.png';

  // Rank tier shields, indexed by RankTier.
  static const tierBronze = 'assets/images/tier_bronze.png';
  static const tierSilver = 'assets/images/tier_silver.png';
  static const tierGold = 'assets/images/tier_gold.png';
  static const tierPlatinum = 'assets/images/tier_platinum.png';
  static const tierDiamond = 'assets/images/tier_diamond.png';
  static const tierMaster = 'assets/images/tier_master.png';
  static const tierGrandmaster = 'assets/images/tier_grandmaster.png';

  // Circular avatar frames.
  static const frameBronze = 'assets/images/frame_bronze.png';
  static const frameSilver = 'assets/images/frame_silver.png';
  static const frameGold = 'assets/images/frame_gold.png';
  static const frameEpic = 'assets/images/frame_epic.png';

  // Emote reaction bubbles.
  static const emoteLaugh = 'assets/images/emote_laugh.png';
  static const emoteAngry = 'assets/images/emote_angry.png';
  static const emoteCool = 'assets/images/emote_cool.png';
  static const emoteCry = 'assets/images/emote_cry.png';
  static const emoteShock = 'assets/images/emote_shock.png';
  static const emoteClap = 'assets/images/emote_clap.png';

  static const btnPlay = 'assets/images/btn_play_gold.png';
  static const btnStart = 'assets/images/btn_start.png';
  static const btnJoin = 'assets/images/btn_join.png';
  static const btnReady = 'assets/images/btn_ready.png';
  static const btnInvite = 'assets/images/btn_invite.png';

  /// Shield art for a rank tier wire value (BRONZE, SILVER, ...).
  static String tierShield(String wire) => switch (wire.toUpperCase()) {
        'SILVER' => tierSilver,
        'GOLD' => tierGold,
        'PLATINUM' => tierPlatinum,
        'DIAMOND' => tierDiamond,
        'MASTER' => tierMaster,
        'GRANDMASTER' => tierGrandmaster,
        _ => tierBronze,
      };

  /// Avatar frame that escalates with player level.
  static String frameForLevel(int level) {
    if (level >= 30) return frameEpic;
    if (level >= 20) return frameGold;
    if (level >= 10) return frameSilver;
    return frameBronze;
  }

  /// Card-back skin art for a store itemId, or null when the item is not a
  /// card back with bespoke art.
  ///
  /// Matched exactly rather than by substring: 'frame_gold' and 'table_...'
  /// both contain words that used to collide with a card-back skin here.
  static String? cardSkin(String itemId) => switch (itemId) {
        'card_back_classic' => skinClassic,
        'card_back_neon' => skinNeon,
        'card_back_gold' => skinGold,
        'card_back_diamond' => skinDiamond,
        'card_back_fire' => skinFire,
        'card_back_ocean' => skinOcean,
        _ => null,
      };

  /// Thumbnail for any store item, or null when it has none.
  ///
  /// Every purchasable item now has its own picture. Previously only card
  /// backs did, and everything else fell back to one generic bundle image,
  /// so a table, a frame and an emote all looked identical in the shop.
  static String? storePreview(String itemId) =>
      cardSkin(itemId) ??
      switch (itemId) {
        'table_galaxy' => tableGalaxy,
        'table_midnight' => tableMidnight,
        'table_aurora' => tableAurora,
        'frame_bronze' => frameBronze,
        'frame_silver' => frameSilver,
        'frame_gold' => frameGold,
        'frame_epic' => frameEpic,
        'badge_star' => medalStar,
        'badge_cards' => medalCards,
        'badge_first' => medalFirst,
        'badge_flame' => medalFlame,
        'badge_bolt' => medalBolt,
        'badge_crown' => medalCrown,
        'avatar_warrior' => avatarWarrior,
        'avatar_wizard' => avatarWizard,
        'avatar_rogue' => avatarRogue,
        'avatar_queen' => avatarQueen,
        _ => itemId.startsWith('emote_')
            ? emote(itemId.substring('emote_'.length))
            : null,
      };

  /// Portrait art for a store avatar itemId, or null when it is not one.
  static String? avatar(String itemId) => switch (itemId) {
        'avatar_warrior' => avatarWarrior,
        'avatar_wizard' => avatarWizard,
        'avatar_rogue' => avatarRogue,
        'avatar_queen' => avatarQueen,
        _ => null,
      };

  /// Medal art for a store badge itemId, or null when it is not a badge.
  static String? badge(String itemId) => switch (itemId) {
        'badge_star' => medalStar,
        'badge_cards' => medalCards,
        'badge_first' => medalFirst,
        'badge_flame' => medalFlame,
        'badge_bolt' => medalBolt,
        'badge_crown' => medalCrown,
        _ => null,
      };

  /// Medal art cycled by achievement index.
  static String medalFor(int index) {
    const all = [
      medalStar, medalCards, medalFirst, medalFlame, medalBolt, medalCrown,
    ];
    return all[index % all.length];
  }

  /// Bubble art for an emote key, or null if that key has no art.
  static String? emote(String key) => switch (key) {
        'laugh' => emoteLaugh,
        'angry' => emoteAngry,
        'cool' => emoteCool,
        'cry' => emoteCry,
        'shock' => emoteShock,
        'clap' => emoteClap,
        _ => null,
      };
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
