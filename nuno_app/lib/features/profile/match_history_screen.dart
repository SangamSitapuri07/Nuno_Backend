import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_states.dart';
import '../../data/models/enums.dart';
import '../../core/widgets/titled_panel.dart';
import '../home/home_providers.dart';

/// Match History — reached from the Play Menu. Backed by GET /api/v1/history.
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);

    return PanelScreen(
      title: 'Match History',
      onBack: () => context.pop(),
      padding: const EdgeInsets.all(AppDimens.md),
      fillHeight: true,
      child: history.when(
          loading: () => ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: AppDimens.sm),
              child: SkeletonListTile(),
            ),
          ),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.invalidate(matchHistoryProvider),
          ),
          data: (matches) {
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.history_rounded,
                title: 'No matches yet',
                message: 'Play a game to build your history.',
              );
            }
            return ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final m = matches[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: AppDimens.brSm,
                    border: Border.all(
                      color: m.isWinner
                          ? AppColors.green.withValues(alpha: 0.45)
                          : AppColors.surfaceStroke,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.isWinner
                            ? Icons.emoji_events_rounded
                            : Icons.close_rounded,
                        size: 16,
                        color: m.isWinner ? AppColors.green : AppColors.danger,
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.isWinner ? 'Victory' : 'Defeat',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: m.isWinner
                                    ? AppColors.green
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${m.gameMode.label} · ${m.durationLabel} · ${Formatters.relativeTime(m.startedAt)}',
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.ratingChange >= 0 ? '+' : ''}${m.ratingChange}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w800,
                              color: m.ratingChange >= 0
                                  ? AppColors.green
                                  : AppColors.danger,
                            ),
                          ),
                          Text('+${m.xpEarned} XP',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
        },
      ),
    );
  }
}
