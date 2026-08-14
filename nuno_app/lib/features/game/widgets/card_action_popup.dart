import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// Screen 9 — Card Action popup. Shows the wild card being played on the left
/// and a colour list on the right; confirm with PLAY CARD.
class CardActionPopup extends StatefulWidget {
  final GameCard card;

  const CardActionPopup({super.key, required this.card});

  static Future<CardColor?> show(
    BuildContext context, {
    required GameCard card,
  }) =>
      showDialog<CardColor>(
        context: context,
        barrierDismissible: true,
        builder: (_) => CardActionPopup(card: card),
      );

  @override
  State<CardActionPopup> createState() => _CardActionPopupState();
}

class _CardActionPopupState extends State<CardActionPopup> {
  CardColor _selected = CardColor.red;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: AppDimens.panelHeaderHeight,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.panelHeader,
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceStroke),
                ),
              ),
              child: Text('CARD ACTION', style: AppTextStyles.panelTitle),
            ),

            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CHOOSE ACTION', style: AppTextStyles.label),
                  const SizedBox(height: AppDimens.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card preview
                      Column(
                        children: [
                          PlayingCardView(card: widget.card, width: 58),
                          const SizedBox(height: 4),
                          Text(
                            widget.card.value.label,
                            style: AppTextStyles.caption.copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppDimens.lg),
                      // Colour choices
                      Expanded(
                        child: Column(
                          children: [
                            for (final c in CardColorX.pickable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _ColorRow(
                                  color: c,
                                  selected: _selected == c,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selected = c);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.md),
                  AppButton(
                    label: 'PLAY CARD',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(_selected);
                    },
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

class _ColorRow extends StatelessWidget {
  final CardColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorRow({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(color.wire);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
        decoration: BoxDecoration(
          color: selected
              ? swatch.withValues(alpha: 0.22)
              : AppColors.surfaceHigh,
          borderRadius: AppDimens.brSm,
          border: Border.all(
            color: selected ? swatch : AppColors.surfaceStroke,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Text(
                color.label,
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 15, color: swatch),
          ],
        ),
      ),
    );
  }
}
