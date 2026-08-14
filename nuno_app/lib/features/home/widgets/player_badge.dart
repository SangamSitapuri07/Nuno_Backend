import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../core/widgets/player_avatar.dart';
import '../../../data/models/enums.dart';

/// Top-left identity card: avatar, username, a level XP bar and a tier pill.
class PlayerBadge extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tierColor = AppColors.forTier(tier.wire);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 268,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.sm,
          vertical: AppDimens.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE60E1030),
          borderRadius: AppDimens.brLg,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with a violet ring.
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PlayerAvatar(
                    username: username,
                    avatarUrl: avatarUrl,
                    size: 38,
                  ),
                  ArtImage(Art.frameForLevel(level), width: 54),
                ],
              ),
            ),

            const SizedBox(width: AppDimens.sm),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
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
              height: 44,
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
