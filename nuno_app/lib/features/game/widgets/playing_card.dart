import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/game_card.dart';

/// A single Nuno playing card face.
///
/// Layout mirrors a classic UNO card: white rounded frame, coloured body, a
/// white ellipse rotated across the middle and the value glyph repeated in the
/// centre and both opposite corners. Wild cards render the four-colour pinwheel.
class PlayingCardView extends StatelessWidget {
  final GameCard card;
  final double width;

  /// Dim the card when it can't legally be played.
  final bool isPlayable;

  /// Lift + glow, used for the currently selected hand card.
  final bool isSelected;

  /// Overrides the body colour (used to show the chosen colour of a wild card
  /// once it is on the discard pile).
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
        ? const _WildPinwheel()
        : ColoredBox(color: AppColors.forCardColor(_color.wire));

    final glyph = card.value.glyph;
    final centreFontSize = glyph.length > 2 ? width * 0.34 : width * 0.46;
    final cornerFontSize = width * 0.19;

    Widget cardFace = Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.5 : 0.32),
            blurRadius: isSelected ? 18 : 8,
            offset: Offset(0, isSelected ? 10 : 4),
          ),
          if (isSelected)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.55),
              blurRadius: 22,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,

            // White ellipse across the middle.
            Center(
              child: Transform.rotate(
                angle: -math.pi / 5.2,
                child: Container(
                  width: width * 0.92,
                  height: _height * 0.52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
            ),

            // Centre glyph.
            Center(
              child: _GlyphText(
                text: glyph,
                fontSize: centreFontSize,
                color: _isWildFace
                    ? AppColors.cardWild
                    : AppColors.forCardColor(_color.wire),
                withStroke: true,
              ),
            ),

            // Top-left corner glyph.
            Positioned(
              top: width * 0.03,
              left: width * 0.07,
              child: _GlyphText(
                text: glyph,
                fontSize: cornerFontSize,
                color: Colors.white,
              ),
            ),

            // Bottom-right corner glyph (rotated 180°).
            Positioned(
              bottom: width * 0.03,
              right: width * 0.07,
              child: Transform.rotate(
                angle: math.pi,
                child: _GlyphText(
                  text: glyph,
                  fontSize: cornerFontSize,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isPlayable) {
      cardFace = Opacity(
        opacity: 0.42,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFF3A3550),
            BlendMode.saturation,
          ),
          child: cardFace,
        ),
      );
    }

    if (onTap == null) return cardFace;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cardFace,
    );
  }
}

class _GlyphText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final bool withStroke;

  const _GlyphText({
    required this.text,
    required this.fontSize,
    required this.color,
    this.withStroke = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!withStroke) {
      return Text(
        text,
        style: AppTextStyles.cardGlyph(fontSize).copyWith(color: color),
      );
    }

    // Outlined text: stroke pass behind a solid fill pass.
    return Stack(
      children: [
        Text(
          text,
          style: AppTextStyles.cardGlyph(fontSize).copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.07
              ..color = Colors.black.withValues(alpha: 0.18),
          ),
        ),
        Text(
          text,
          style: AppTextStyles.cardGlyph(fontSize).copyWith(color: color),
        ),
      ],
    );
  }
}

/// Four-quadrant colour wheel shown on wild cards.
class _WildPinwheel extends StatelessWidget {
  const _WildPinwheel();

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

/// Face-down card, used for opponent hands and the draw pile.
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          if (isHighlighted)
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2350), Color(0xFF14112C)],
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -math.pi / 5.2,
                child: Container(
                  width: width * 0.9,
                  height: _height * 0.5,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'NUNO',
                style: AppTextStyles.cardGlyph(width * 0.2).copyWith(
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return onTap == null
        ? face
        : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: face);
  }
}
