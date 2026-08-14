import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/utils/formatters.dart';
import '../home_providers.dart';

/// Bottom sheet listing GET /api/v1/notifications
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const NotificationsSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXxl),
          ),
          border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppDimens.md),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceStroke,
                borderRadius: AppDimens.brPill,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.xxl,
                AppDimens.lg,
                AppDimens.lg,
                AppDimens.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Notifications', style: AppTextStyles.h2),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(notificationsProvider.notifier).markAllRead(),
                    child: Text(
                      'Mark all read',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.when(
                loading: () => ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.xxl),
                  itemCount: 5,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: AppDimens.md),
                    child: SkeletonListTile(),
                  ),
                ),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
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
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.xxl,
                      0,
                      AppDimens.xxl,
                      AppDimens.xxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimens.md),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return Container(
                        padding: const EdgeInsets.all(AppDimens.lg),
                        decoration: BoxDecoration(
                          color: n.read
                              ? AppColors.surface
                              : AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: AppDimens.brLg,
                          border: Border.all(
                            color: n.read
                                ? AppColors.surfaceStroke
                                : AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: n.read
                                    ? AppColors.textMuted
                                    : AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppDimens.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: AppTextStyles.h4),
                                  const SizedBox(height: 2),
                                  Text(n.message,
                                      style: AppTextStyles.bodySm),
                                  const SizedBox(height: AppDimens.sm),
                                  Text(
                                    Formatters.relativeTime(n.createdAt),
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
