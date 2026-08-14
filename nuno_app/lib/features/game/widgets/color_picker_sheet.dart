import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/enums.dart';

/// Modal shown after playing a Wild / Wild Draw Four so the player can pick the
/// next colour (sent as `selectedColor` on the card.play payload).
class ColorPickerSheet extends StatelessWidget {
  const ColorPickerSheet({super.key});

  static Future<CardColor?> show(BuildContext context) => showModalBottomSheet<CardColor>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => const ColorPickerSheet(),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXxl)),
        border: Border(top: BorderSide(color: AppColors.surfaceStroke)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.xxl,
        AppDimens.xl,
        AppDimens.xxl,
        MediaQuery.paddingOf(context).bottom + AppDimens.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Choose a colour', style: AppTextStyles.h2),
          const SizedBox(height: AppDimens.xs),
          Text(
            'The next player must match this colour.',
            style: AppTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.xxl),
          Row(
            children: [
              for (final color in CardColorX.pickable) ...[
                Expanded(child: _ColorTile(color: color)),
                if (color != CardColorX.pickable.last)
                  const SizedBox(width: AppDimens.md),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final CardColor color;

  const _ColorTile({required this.color});

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(color.wire);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(color);
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: AppDimens.brLg,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: swatch.withValues(alpha: 0.55),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            color.label[0],
            style: AppTextStyles.cardGlyph(30).copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
