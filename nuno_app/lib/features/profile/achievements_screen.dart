import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/user_models.dart';
import '../home/home_providers.dart';

/// Screen 21 — Achievements.
///
/// The backend has no achievements model, so progress is derived client-side
/// from GET /api/v1/statistics. Swap `_definitions` for a real endpoint when
/// one exists.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider).valueOrNull;

    return PanelScreen(
      title: 'Achievements',
      onBack: () => context.pop(),
      maxWidth: 560,
      padding: const EdgeInsets.all(AppDimens.md),
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          itemCount: _definitions.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
          itemBuilder: (context, i) {
            final def = _definitions[i];
            final current = stats == null ? 0 : def.progress(stats);
            return _AchievementTile(
              def: def,
              current: current.clamp(0, def.target),
            );
          },
        ),
      ),
    );
  }

  static final List<_AchievementDef> _definitions = [
    _AchievementDef(
      title: 'First Win',
      description: 'Win your first match',
      icon: Icons.star_rounded,
      color: AppColors.gold,
      target: 1,
      progress: (s) => s.gamesWon,
    ),
    _AchievementDef(
      title: 'UNO Master',
      description: 'Declare UNO 50 times',
      icon: Icons.style_rounded,
      color: AppColors.primary,
      target: 50,
      // No server counter for UNO calls; approximate with wins.
      progress: (s) => s.gamesWon,
    ),
    _AchievementDef(
      title: 'Winner',
      description: 'Win 100 matches',
      icon: Icons.emoji_events_rounded,
      color: AppColors.blue,
      target: 100,
      progress: (s) => s.gamesWon,
    ),
    _AchievementDef(
      title: 'Veteran',
      description: 'Play 250 matches',
      icon: Icons.military_tech_rounded,
      color: AppColors.rarityEpic,
      target: 250,
      progress: (s) => s.gamesPlayed,
    ),
    _AchievementDef(
      title: 'On Fire',
      description: 'Reach a 10 win streak',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.warning,
      target: 10,
      progress: (s) => s.longestWinStreak,
    ),
    _AchievementDef(
      title: 'Card Shark',
      description: 'Play 1000 cards',
      icon: Icons.layers_rounded,
      color: AppColors.green,
      target: 1000,
      progress: (s) => s.cardsPlayed,
    ),
  ];
}

class _AchievementDef {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(PlayerStats) progress;

  _AchievementDef({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.target,
    required this.progress,
  });
}

class _AchievementTile extends StatelessWidget {
  final _AchievementDef def;
  final int current;

  const _AchievementTile({required this.def, required this.current});

  @override
  Widget build(BuildContext context) {
    final complete = current >= def.target;
    final ratio = def.target == 0 ? 0.0 : current / def.target;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppDimens.brSm,
        border: Border.all(
          color: complete
              ? def.color.withValues(alpha: 0.6)
              : AppColors.surfaceStroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: complete ? 0.25 : 0.10),
              borderRadius: AppDimens.brSm,
            ),
            child: Icon(
              def.icon,
              size: 18,
              color: complete ? def.color : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        def.title,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: complete
                              ? def.color
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (complete)
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: def.color)
                    else
                      Text(
                        '($current/${def.target})',
                        style: AppTextStyles.caption.copyWith(fontSize: 9),
                      ),
                  ],
                ),
                Text(
                  def.description,
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: AppDimens.brPill,
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation(def.color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
