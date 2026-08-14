import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// Centre of the table: rotating direction ring, draw pile, discard pile and
/// the "YOUR TURN" banner from screen 8.
class TableCenter extends StatelessWidget {
  final GameCard? topCard;
  final CardColor currentColor;
  final int drawPileCount;
  final GameDirection direction;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool showYourTurn;

  const TableCenter({
    super.key,
    required this.topCard,
    required this.currentColor,
    required this.drawPileCount,
    required this.direction,
    required this.canDraw,
    required this.onDraw,
    this.showYourTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showYourTurn) ...[
          const _YourTurnBanner(),
          const SizedBox(height: AppDimens.sm),
        ],
        Stack(
          alignment: Alignment.center,
          children: [
            _DirectionRing(direction: direction, color: currentColor),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Draw pile
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 3,
                          top: 3,
                          child: Opacity(
                            opacity: 0.6,
                            child: CardBackView(
                              width: AppDimens.tableCardWidth * 0.9,
                            ),
                          ),
                        ),
                        CardBackView(
                          width: AppDimens.tableCardWidth * 0.9,
                          isHighlighted: canDraw,
                          onTap: canDraw ? onDraw : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$drawPileCount',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ),

                const SizedBox(width: AppDimens.lg),

                // Discard pile
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween(begin: 0.75, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: topCard == null
                          ? const _EmptySlot(key: ValueKey('empty'))
                          : Transform.rotate(
                              key: ValueKey(topCard!.cardId),
                              angle: -0.05,
                              child: PlayingCardView(
                                card: topCard!,
                                width: AppDimens.tableCardWidth,
                                overrideColor: topCard!.color.isWild &&
                                        !currentColor.isWild
                                    ? currentColor
                                    : null,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    _ColorDot(color: currentColor),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _YourTurnBanner extends StatefulWidget {
  const _YourTurnBanner();

  @override
  State<_YourTurnBanner> createState() => _YourTurnBannerState();
}

class _YourTurnBannerState extends State<_YourTurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.65, end: 1.0).animate(_c),
      child: Text(
        'YOUR TURN',
        style: AppTextStyles.h4.copyWith(
          color: const Color(0xFF7CFFA8),
          letterSpacing: 2,
          fontSize: 13,
          shadows: [
            Shadow(
              color: AppColors.green.withValues(alpha: 0.9),
              blurRadius: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.tableCardWidth,
      height: AppDimens.tableCardHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppDimens.tableCardWidth * 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final CardColor color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(color.wire);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: 34,
      height: 6,
      decoration: BoxDecoration(
        color: swatch,
        borderRadius: AppDimens.brPill,
        boxShadow: [
          BoxShadow(color: swatch.withValues(alpha: 0.7), blurRadius: 8),
        ],
      ),
    );
  }
}

/// Rotating dashed ring showing play direction.
class _DirectionRing extends StatefulWidget {
  final GameDirection direction;
  final CardColor color;

  const _DirectionRing({required this.direction, required this.color});

  @override
  State<_DirectionRing> createState() => _DirectionRingState();
}

class _DirectionRingState extends State<_DirectionRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.direction == GameDirection.clockwise ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.rotate(
        angle: _c.value * 2 * math.pi * sign,
        child: CustomPaint(
          size: const Size(190, 150),
          painter: _RingPainter(
            color: AppColors.forCardColor(widget.color.wire),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;

  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width,
      height: size.height,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28);

    const segments = 20;
    const sweep = (2 * math.pi / segments) * 0.5;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(rect, (2 * math.pi / segments) * i, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.color != color;
}
