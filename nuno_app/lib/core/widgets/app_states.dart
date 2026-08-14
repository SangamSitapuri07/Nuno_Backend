import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// Full-area empty state with an optional CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceStroke),
              ),
              child: Icon(icon, size: 38, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppDimens.xl),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppDimens.sm),
              Text(
                message!,
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimens.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.medium,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-area error state with retry.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        message: message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Branded loading indicator.
class LoadingView extends StatelessWidget {
  final String? label;

  const LoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (label != null) ...[
            const SizedBox(height: AppDimens.lg),
            Text(label!, style: AppTextStyles.bodySm),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block for list skeletons.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppDimens.brSm,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Skeleton row matching the list-tile layout used by friends/leaderboard.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      child: Row(
        children: [
          const SkeletonBox(
            width: AppDimens.avatarMd,
            height: AppDimens.avatarMd,
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 130, height: 14),
                SizedBox(height: AppDimens.sm),
                SkeletonBox(width: 80, height: 11),
              ],
            ),
          ),
          const SkeletonBox(width: 52, height: 26, borderRadius: AppDimens.brSm),
        ],
      ),
    );
  }
}

/// Convenience snackbars.
class AppSnack {
  AppSnack._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                icon ??
                    (isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded),
                color: isError ? AppColors.danger : AppColors.success,
                size: 20,
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(child: Text(message, style: AppTextStyles.body)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void error(BuildContext context, String message) =>
      show(context, message, isError: true);
}
