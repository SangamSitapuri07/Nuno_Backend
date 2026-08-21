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
        constraints: const BoxConstraints(maxWidth: 250, minWidth: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.sm,
          vertical: 6,
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
              width: 42,
              height: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PlayerAvatar(
                    username: username,
                    // An equipped portrait wins over the account picture.
                    avatarUrl: cosmetics.avatar ?? avatarUrl,
                    size: 32,
                  ),
                  // Height pinned as well as width: the frame art is very
                  // close to square but not exactly, and without this the
                  // ring grows past the 42x42 slot.
                  ArtImage(frame, width: 42, height: 42),
                ],
              ),
            ),

            const SizedBox(width: AppDimens.sm),

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
                          style: AppTextStyles.h4.copyWith(fontSize: 14),
                        ),
                      ),
                      // Equipped badge, beside the name.
                      if (cosmetics.badge != null) ...[
                        const SizedBox(width: 4),
                        ArtImage(cosmetics.badge!, width: 16),
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
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Lv. $level',
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: 12,
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
                            minHeight: 6,
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

            const SizedBox(width: AppDimens.sm),

            // Tier shield
            ArtImage(
              Art.tierShield(tier.wire),
              height: 38,
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
