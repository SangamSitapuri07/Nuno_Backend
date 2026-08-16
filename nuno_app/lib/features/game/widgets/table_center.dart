import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// Centre of the table: a glowing orange vortex with the draw pile on the left
/// and the discard pile on the right, plus curved direction arrows.
class TableCenter extends StatelessWidget {
  final GameCard? topCard;
  final CardColor currentColor;
  final int drawPileCount;
  final GameDirection direction;
  final bool canDraw;
  final VoidCallback onDraw;
  final Key? drawPileKey;

  const TableCenter({
    super.key,
    required this.topCard,
    required this.currentColor,
    required this.drawPileCount,
    required this.direction,
    required this.canDraw,
    required this.onDraw,
    this.drawPileKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The vortex is painted into bg_table.jpg, so only a soft lift
          // is needed here to seat the piles against it.
          Container(
            width: 260,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Rotating direction arrows.
          _DirectionArrows(direction: direction),

          // Piles.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DrawPile(
                key: drawPileKey,
                count: drawPileCount,
                canDraw: canDraw,
                onDraw: onDraw,
              ),
              const SizedBox(width: AppDimens.xl),
              _DiscardPile(topCard: topCard, currentColor: currentColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawPile extends StatelessWidget {
  final int count;
  final bool canDraw;
  final VoidCallback onDraw;

  const _DrawPile({
    super.key,
    required this.count,
    required this.canDraw,
    required this.onDraw,
  });

  @override
  Widget build(BuildContext context) {
    const w = 76.0;

    return SizedBox(
      width: w + 10,
      height: w / 0.68 + 12,
      child: Stack(
        children: [
          // Stacked white edges suggesting depth.
          for (var i = 4; i >= 1; i--)
            Positioned(
              left: 2.0 - i * 0.5,
              top: i * 1.8,
              child: Container(
                width: w,
                height: w / 0.68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(w * 0.13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          CardBackView(
            width: w,
            isHighlighted: canDraw,
            onTap: canDraw ? onDraw : null,
          ),
        ],
      ),
    );
  }
}

class _DiscardPile extends StatelessWidget {
  final GameCard? topCard;
  final CardColor currentColor;

  const _DiscardPile({required this.topCard, required this.currentColor});

  @override
  Widget build(BuildContext context) {
    const w = 82.0;

    if (topCard == null) {
      return Container(
        width: w,
        height: w / 0.68,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(w * 0.13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
      );
    }

    return SizedBox(
      width: w + 22,
      height: w / 0.68 + 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Two scattered cards beneath, as in the mockup.
          Transform.translate(
            offset: const Offset(10, 8),
            child: Transform.rotate(
              angle: 0.18,
              child: Container(
                width: w,
                height: w / 0.68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(w * 0.13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-6, 4),
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: w,
                height: w / 0.68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(w * 0.13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.78, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: PlayingCardView(
              key: ValueKey(topCard!.cardId),
              card: topCard!,
              width: w,
              overrideColor: topCard!.color.isWild && !currentColor.isWild
                  ? currentColor
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two curved arrows circling the piles to show play direction.
class _DirectionArrows extends StatefulWidget {
  final GameDirection direction;

  const _DirectionArrows({required this.direction});

  @override
  State<_DirectionArrows> createState() => _DirectionArrowsState();
}

class _DirectionArrowsState extends State<_DirectionArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
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
          size: const Size(300, 230),
          painter: _ArrowPainter(),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.86,
      height: size.height * 0.86,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFA726).withValues(alpha: 0.75);

    // Two opposing arcs.
    canvas.drawArc(rect, -0.55, 1.15, false, paint);
    canvas.drawArc(rect, math.pi - 0.55, 1.15, false, paint);

    // Arrow heads at each arc end.
    _head(canvas, rect, 0.60, paint.color);
    _head(canvas, rect, math.pi + 0.60, paint.color);
  }

  void _head(Canvas canvas, Rect rect, double angle, Color color) {
    final cx = rect.center.dx + math.cos(angle) * rect.width / 2;
    final cy = rect.center.dy + math.sin(angle) * rect.height / 2;

    final path = Path();
    const s = 15.0;
    final dir = angle + math.pi / 2;
    path.moveTo(cx + math.cos(dir) * s, cy + math.sin(dir) * s);
    path.lineTo(
      cx + math.cos(dir + 2.4) * s,
      cy + math.sin(dir + 2.4) * s,
    );
    path.lineTo(
      cx + math.cos(dir - 2.4) * s,
      cy + math.sin(dir - 2.4) * s,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
