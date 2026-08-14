import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// Draw pile + discard pile + active-colour indicator + direction arrows.
class TableCenter extends StatelessWidget {
  final GameCard? topCard;
  final CardColor currentColor;
  final int drawPileCount;
  final GameDirection direction;
  final bool canDraw;
  final VoidCallback onDraw;

  const TableCenter({
    super.key,
    required this.topCard,
    required this.currentColor,
    required this.drawPileCount,
    required this.direction,
    required this.canDraw,
    required this.onDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Direction ring behind the piles.
        _DirectionRing(direction: direction, color: currentColor),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Draw pile ────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Depth shadows.
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Opacity(
                        opacity: 0.5,
                        child: CardBackView(
                          width: AppDimens.tableCardWidth * 0.92,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2,
                      top: 2,
                      child: Opacity(
                        opacity: 0.75,
                        child: CardBackView(
                          width: AppDimens.tableCardWidth * 0.92,
                        ),
                      ),
                    ),
                    CardBackView(
                      width: AppDimens.tableCardWidth * 0.92,
                      isHighlighted: canDraw,
                      onTap: canDraw ? onDraw : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: AppDimens.brPill,
                  ),
                  child: Text(
                    '$drawPileCount left',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppDimens.xl),

            // ── Discard pile ─────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween(begin: 0.7, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: topCard == null
                      ? _EmptyDiscardSlot(
                          key: const ValueKey('empty'),
                        )
                      : Transform.rotate(
                          key: ValueKey(topCard!.cardId),
                          angle: -0.06,
                          child: PlayingCardView(
                            card: topCard!,
                            width: AppDimens.tableCardWidth,
                            // Show the chosen colour for played wilds.
                            overrideColor: topCard!.color.isWild &&
                                    !currentColor.isWild
                                ? currentColor
                                : null,
                          ),
                        ),
                ),
                const SizedBox(height: AppDimens.sm),
                _ActiveColorPill(color: currentColor),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyDiscardSlot extends StatelessWidget {
  const _EmptyDiscardSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.tableCardWidth,
      height: AppDimens.tableCardHeight,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimens.tableCardWidth * 0.14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
      ),
    );
  }
}

class _ActiveColorPill extends StatelessWidget {
  final CardColor color;

  const _ActiveColorPill({required this.color});

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(color.wire);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: swatch.withValues(alpha: 0.22),
        borderRadius: AppDimens.brPill,
        border: Border.all(color: swatch, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            color.isWild ? 'ANY' : color.label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotating dashed ring indicating play direction.
class _DirectionRing extends StatefulWidget {
  final GameDirection direction;
  final CardColor color;

  const _DirectionRing({required this.direction, required this.color});

  @override
  State<_DirectionRing> createState() => _DirectionRingState();
}

class _DirectionRingState extends State<_DirectionRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(widget.color.wire);
    final sign =
        widget.direction == GameDirection.clockwise ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.rotate(
        angle: _controller.value * 2 * math.pi * sign,
        child: CustomPaint(
          size: const Size(230, 230),
          painter: _RingPainter(color: swatch),
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
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.30);

    // Dashed circle: 16 arcs.
    const segments = 16;
    const sweep = (2 * math.pi / segments) * 0.55;
    for (var i = 0; i < segments; i++) {
      final start = (2 * math.pi / segments) * i;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.color != color;
}
