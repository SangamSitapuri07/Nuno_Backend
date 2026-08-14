import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// Screen 10 — "UNO!" declaration burst.
class UnoDeclaredOverlay extends StatelessWidget {
  final String message;

  const UnoDeclaredOverlay({
    super.key,
    this.message = 'You have declared UNO',
  });

  static Future<void> show(
    BuildContext context, {
    String message = 'You have declared UNO',
  }) =>
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => UnoDeclaredOverlay(message: message),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppDimens.xxl),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(240, 150),
                    painter: _StarburstPainter(),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'UNO!',
                        style: AppTextStyles.cardGlyph(62).copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 7
                            ..strokeJoin = StrokeJoin.round
                            ..color = Colors.white,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                        ).createShader(r),
                        child: Text(
                          'UNO!',
                          style: AppTextStyles.cardGlyph(62)
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: 130,
              child: AppButton(
                label: 'OK',
                size: AppButtonSize.small,
                variant: AppButtonVariant.gold,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.fill;
    const spikes = 16;

    for (var i = 0; i < spikes; i++) {
      final angle = (2 * math.pi / spikes) * i;
      final long = i.isEven ? size.width * 0.52 : size.width * 0.40;
      paint.color = (i.isEven ? AppColors.gold : AppColors.primary)
          .withValues(alpha: 0.30);

      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(
          centre.dx + math.cos(angle - 0.13) * long * 0.5,
          centre.dy + math.sin(angle - 0.13) * long * 0.5,
        )
        ..lineTo(
          centre.dx + math.cos(angle) * long,
          centre.dy + math.sin(angle) * long,
        )
        ..lineTo(
          centre.dx + math.cos(angle + 0.13) * long * 0.5,
          centre.dy + math.sin(angle + 0.13) * long * 0.5,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Screen 11 — Draw Penalty. Shows the cards you must pick up.
class DrawPenaltyOverlay extends StatelessWidget {
  final int count;

  const DrawPenaltyOverlay({super.key, required this.count});

  static Future<void> show(BuildContext context, {required int count}) =>
      showDialog(
        context: context,
        builder: (_) => DrawPenaltyOverlay(count: count),
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
              child: Text('DRAW PENALTY', style: AppTextStyles.panelTitle),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: AppDimens.brPill,
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      'DRAW $count CARD${count == 1 ? '' : 'S'}',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  SizedBox(
                    height: 62,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < count.clamp(1, 4); i++)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Transform.rotate(
                              angle: (i - (count.clamp(1, 4) - 1) / 2) * 0.10,
                              child: const PlayingCardView(
                                card: GameCard(
                                  cardId: 'penalty',
                                  color: CardColor.wild,
                                  value: CardValue.wildDrawFour,
                                ),
                                width: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.md),
                  Text(
                    'You have to draw $count cards',
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: AppDimens.lg),
                  SizedBox(
                    width: 130,
                    child: AppButton(
                      label: 'OK',
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.gold,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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
