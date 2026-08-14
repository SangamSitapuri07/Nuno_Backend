import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/titled_panel.dart';
import '../home/home_providers.dart';

/// Screen 26 — Notifications, backed by GET /api/v1/notifications.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return PanelScreen(
      title: 'Notifications',
      onBack: () => context.pop(),
      maxWidth: 560,
      padding: const EdgeInsets.all(AppDimens.md),
      trailing: IconButton(
        icon: const Icon(Icons.done_all_rounded,
            size: 16, color: AppColors.textSecondary),
        tooltip: 'Mark all read',
        onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
      ),
      child: SizedBox(
        height: 250,
        child: notifications.when(
          loading: () => ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: AppDimens.sm),
              child: SkeletonListTile(),
            ),
          ),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'No notifications',
                message: 'You are all caught up.',
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final n = items[i];
                return Container(
                  padding: const EdgeInsets.all(AppDimens.sm),
                  decoration: BoxDecoration(
                    color: n.read
                        ? AppColors.surfaceHigh
                        : AppColors.blue.withValues(alpha: 0.10),
                    borderRadius: AppDimens.brSm,
                    border: Border.all(
                      color: n.read
                          ? AppColors.surfaceStroke
                          : AppColors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerAvatar(username: n.title, size: 26),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              n.message,
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.relativeTime(n.createdAt),
                        style: AppTextStyles.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
