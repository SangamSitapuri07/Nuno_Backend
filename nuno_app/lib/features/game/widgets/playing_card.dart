import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_assets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';

/// A Nuno card face, matching the gameplay mockup.
///
/// White rounded frame, coloured body, a white ellipse rotated across the
/// middle, the big outlined value in the centre and a small corner glyph.
class PlayingCardView extends StatelessWidget {
  final GameCard card;
  final double width;
  final bool isPlayable;
  final bool isSelected;
  final CardColor? overrideColor;
  final VoidCallback? onTap;

  const PlayingCardView({
    super.key,
    required this.card,
    this.width = 78,
    this.isPlayable = true,
    this.isSelected = false,
    this.overrideColor,
    this.onTap,
  });

  double get _height => width / 0.68;

  CardColor get _color => overrideColor ?? card.color;

  bool get _isWildFace => card.isWild && overrideColor == null;

  @override
  Widget build(BuildContext context) {
    final body = _isWildFace
        ? const _WildQuadrants()
        : ColoredBox(color: AppColors.forCardColor(_color.wire));

    Widget face = Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.13),
        // No ambient drop shadow: cards in a fanned hand overlap, so every
        // card cast a dark band onto the one beside it, which read as a
        // grey edge rather than depth. Only the selected card is lifted.
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(width * 0.055),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.095),
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,

            // White ellipse across the middle.
            Center(
              child: Transform.rotate(
                angle: -math.pi / 5,
                child: Container(
                  width: width * 0.95,
                  height: _height * 0.50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
            ),

            // Centre symbol.
            Center(child: _CenterSymbol(card: card, color: _color, width: width)),

            // Top-left corner glyph.
            Positioned(
              top: width * 0.04,
              left: width * 0.09,
              child: _CornerGlyph(card: card, size: width * 0.21),
            ),

            // Bottom-right corner glyph, rotated.
            Positioned(
              bottom: width * 0.04,
              right: width * 0.09,
              child: Transform.rotate(
                angle: math.pi,
                child: _CornerGlyph(card: card, size: width * 0.21),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isPlayable) {
      face = Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFF4A4A5A),
            BlendMode.saturation,
          ),
          child: face,
        ),
      );
    }

    if (onTap == null) return face;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: face,
    );
  }
}

/// The large glyph in the middle of the ellipse.
class _CenterSymbol extends StatelessWidget {
  final GameCard card;
  final CardColor color;
  final double width;

  const _CenterSymbol({
    required this.card,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final swatch = AppColors.forCardColor(color.wire);

    switch (card.value) {
      case CardValue.wild:
      case CardValue.wildDrawFour:
        // Four colour swatches inside the ellipse.
        return SizedBox(
          width: width * 0.46,
          height: width * 0.46,
          child: Transform.rotate(
            angle: -math.pi / 5,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: width * 0.045,
              crossAxisSpacing: width * 0.045,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final c in const [
                  AppColors.cardRed,
                  AppColors.cardBlue,
                  AppColors.cardYellow,
                  AppColors.cardGreen,
                ])
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(width * 0.04),
                    ),
                  ),
              ],
            ),
          ),
        );

      case CardValue.skip:
        return Icon(
          Icons.block_rounded,
          size: width * 0.44,
          color: swatch,
          shadows: const [
            Shadow(color: Colors.white, blurRadius: 0, offset: Offset(1.5, 1.5)),
          ],
        );

      case CardValue.reverse:
        return Icon(
          Icons.swap_vert_rounded,
          size: width * 0.46,
          color: swatch,
        );

      case CardValue.drawTwo:
        // Two overlapping card shapes.
        return SizedBox(
          width: width * 0.42,
          height: width * 0.42,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: width * 0.06,
                child: _MiniCard(size: width * 0.24, fill: Colors.white, stroke: swatch),
              ),
              Positioned(
                right: 0,
                bottom: width * 0.06,
                child: _MiniCard(size: width * 0.24, fill: Colors.white, stroke: swatch),
              ),
            ],
          ),
        );

      default:
        return _OutlinedNumber(
          text: card.value.wire,
          fontSize: width * 0.56,
          fill: swatch,
        );
    }
  }
}

class _MiniCard extends StatelessWidget {
  final double size;
  final Color fill;
  final Color stroke;

  const _MiniCard({required this.size, required this.fill, required this.stroke});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.45,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: stroke, width: size * 0.14),
      ),
    );
  }
}

/// Number with a heavy white outline, as on the mockup's card faces.
class _OutlinedNumber extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fill;

  const _OutlinedNumber({
    required this.text,
    required this.fontSize,
    required this.fill,
  });

  TextStyle get _base => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        fontFamily: 'Baloo 2',
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: _base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.10
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        Text(text, style: _base.copyWith(color: fill)),
      ],
    );
  }
}

/// Small white glyph in the card corners.
class _CornerGlyph extends StatelessWidget {
  final GameCard card;
  final double size;

  const _CornerGlyph({required this.card, required this.size});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      height: 1,
      fontFamily: 'Baloo 2',
    );

    switch (card.value) {
      case CardValue.skip:
        return Icon(Icons.block_rounded, size: size, color: Colors.white);
      case CardValue.reverse:
        return Icon(Icons.swap_vert_rounded, size: size, color: Colors.white);
      case CardValue.drawTwo:
        return Text('+2', style: style);
      case CardValue.wildDrawFour:
        return Text('+4', style: style);
      case CardValue.wild:
        return Icon(Icons.palette_rounded, size: size, color: Colors.white);
      default:
        return Text(card.value.wire, style: style);
    }
  }
}

/// Face-down card. Uses the rendered 3D art, falling back to a painted back.
class CardBackView extends StatelessWidget {
  final double width;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const CardBackView({
    super.key,
    this.width = 78,
    this.onTap,
    this.isHighlighted = false,
  });

  double get _height => width / 0.68;

  @override
  Widget build(BuildContext context) {
    final face = Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.13),
        // Matches the card face: no ambient shadow, since stacked backs
        // otherwise smear a dark edge across each other.
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.13),
        child: Image.asset(
          Art.cardBack3d,
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => _PaintedBack(width: width),
        ),
      ),
    );

    return onTap == null
        ? face
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: face,
          );
  }
}

/// Hand-painted card back, used when the asset cannot be loaded.
class _PaintedBack extends StatelessWidget {
  final double width;

  const _PaintedBack({required this.width});

  @override
  Widget build(BuildContext context) {
    final height = width / 0.68;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(width * 0.055),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.095),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0D0D0D)),
            Center(
              child: Transform.rotate(
                angle: -math.pi / 5,
                child: Container(
                  width: width * 0.92,
                  height: height * 0.46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD31820),
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -math.pi / 5,
                child: FittedBox(
                  child: Text(
                    'NUNO',
                    style: TextStyle(
                      fontSize: width * 0.24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -0.5,
                      fontFamily: 'Baloo 2',
                      color: const Color(0xFFFFC400),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Body of an unplayed wild card: the four suit colours in quadrants.
///
/// The previous near-black fill made a wild look like an empty or
/// half-loaded card next to the solid coloured ones.
class _WildQuadrants extends StatelessWidget {
  const _WildQuadrants();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: ColoredBox(color: AppColors.cardRed)),
              Expanded(child: ColoredBox(color: AppColors.cardBlue)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: ColoredBox(color: AppColors.cardYellow)),
              Expanded(child: ColoredBox(color: AppColors.cardGreen)),
            ],
          ),
        ),
      ],
    );
  }
}
