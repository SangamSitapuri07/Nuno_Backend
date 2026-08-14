import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

/// Screen 30 — Exit Confirm.
class ExitConfirmDialog extends StatelessWidget {
  const ExitConfirmDialog({super.key});

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => const ExitConfirmDialog(),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: AppDimens.panelHeaderHeight,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.panelHeader,
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceStroke),
                ),
              ),
              child: Text('EXIT CONFIRM', style: AppTextStyles.panelTitle),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 40, color: AppColors.gold),
                  const SizedBox(height: AppDimens.sm),
                  Text('EXIT GAME?', style: AppTextStyles.h3),
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    'Are you sure you want to leave the game?\nThis counts as a surrender.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: AppDimens.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'CANCEL',
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: AppButton(
                          label: 'EXIT',
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.danger,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
