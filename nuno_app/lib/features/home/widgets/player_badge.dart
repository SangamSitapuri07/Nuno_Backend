import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/enums.dart';
import '../../store/cosmetics_provider.dart';

/// Top-left identity card: avatar, username, a level XP bar and a tier pill.
class PlayerBadge extends ConsumerWidget {
  final String username;
  final String? avatarUrl;
  final int level;
  final double levelProgress;
  final RankTier tier;
  final VoidCallback? onTap;

  const PlayerBadge({
    super.key,
    required this.username,
    this.avatarUrl,
    this.level = 1,
    this.levelProgress = 0,
    this.tier = RankTier.bronze,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierColor = AppColors.forTier(tier.wire);

    // An equipped frame overrides the level-derived one, which is the whole
    // point of buying it. Falls back to the level frame when none is set.
    final cosmetics = ref.watch(equippedCosmeticsProvider);
    final frame = cosmetics.avatarFrame ?? Art.frameForLevel(level);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Sized to its contents rather than a 150px floor.
        //
        // The badge sets the height of the whole header, and it was carrying
        // a 42px avatar inside 6px of padding for a strip that only needs to
        // hold a name and a level bar. Trimming the padding and the avatar
        // takes the header down without shrinking a single glyph.
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xE62A1A5E), Color(0xF21A0F3D)],
          ),
          borderRadius: AppDimens.brLg,
          border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // Centre rather than stretch: the badge is placed in a fixed-height
          // header, and a tall child was overflowing it by a few pixels.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with a violet ring.
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PlayerAvatar(
                    username: username,
                    // An equipped portrait wins over the account picture.
                    avatarUrl: cosmetics.avatar ?? avatarUrl,
                    size: 28,
                  ),
                  // Height pinned as well as width: the frame art is very
                  // close to square but not exactly, and without this the
                  // ring grows past the 42x42 slot.
                  ArtImage(frame, width: 36, height: 36),
                ],
              ),
            ),

            const SizedBox(width: 6),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h4
                              .copyWith(fontSize: 13, height: 1.1),
                        ),
                      ),
                      // Equipped badge, beside the name.
                      if (cosmetics.badge != null) ...[
                        const SizedBox(width: 4),
                        ArtImage(cosmetics.badge!, width: 14),
                      ],
                    ],
                  ),
                  // Equipped title, under the name.
                  if (cosmetics.title != null)
                    Text(
                      cosmetics.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        'Lv. $level',
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: 11,
                          height: 1.1,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // XP bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: AppDimens.brPill,
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.cyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Tier shield
            ArtImage(
              Art.tierShield(tier.wire),
              height: 32,
              fallback: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.14),
                  borderRadius: AppDimens.brSm,
                  border: Border.all(color: tierColor, width: 1.4),
                ),
                child: Text(
                  tier.label.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
