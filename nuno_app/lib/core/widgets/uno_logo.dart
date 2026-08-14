import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The UNO wordmark from the reference: a tilted red oval with thick
/// white-outlined yellow lettering.
class UnoLogo extends StatelessWidget {
  final double width;
  final String text;

  const UnoLogo({super.key, this.width = 260, this.text = 'UNO'});

  @override
  Widget build(BuildContext context) {
    final height = width * 0.52;
    final fontSize = width * 0.30;

    return Transform.rotate(
      angle: -0.06,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF4B50), Color(0xFFC1121A)],
          ),
          borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 42,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: -0.04,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outline pass.
              Text(
                text,
                style: _style(fontSize).copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = fontSize * 0.13
                    ..strokeJoin = StrokeJoin.round
                    ..color = Colors.white,
                ),
              ),
              // Fill pass.
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                ).createShader(rect),
                child: Text(
                  text,
                  style: _style(fontSize).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _style(double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: size * 0.02,
        height: 1.1,
        fontFamily: 'Baloo 2',
      );
}

/// Compact stacked-cards mark for tight spaces (loading, small headers).
class UnoCardMark extends StatelessWidget {
  final double size;

  const UnoCardMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.cardRed,
      AppColors.cardYellow,
      AppColors.cardGreen,
      AppColors.cardBlue,
    ];

    return SizedBox(
      width: size * 1.4,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < colors.length; i++)
            Transform.translate(
              offset: Offset((i - 1.5) * size * 0.22, 0),
              child: Transform.rotate(
                angle: (i - 1.5) * 0.16,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.62,
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(size * 0.08),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -math.pi / 9,
                      child: Container(
                        width: size * 0.2,
                        height: size * 0.34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(size),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
