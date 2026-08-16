import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import 'playing_card.dart';

/// Brief shuffle-and-deal flourish shown when a match opens.
///
/// The table used to appear fully dealt in a single frame, which gave no sense
/// that a round had begun. This covers the first moment of the match while the
/// initial state arrives, then gets out of the way.
class ShuffleIntro extends StatefulWidget {
  final VoidCallback? onComplete;

  const ShuffleIntro({super.key, this.onComplete});

  @override
  State<ShuffleIntro> createState() => _ShuffleIntroState();
}

class _ShuffleIntroState extends State<ShuffleIntro>
    with SingleTickerProviderStateMixin {
  static const int _cardCount = 7;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward().whenComplete(() => widget.onComplete?.call());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // Fade the whole thing out over the last fifth.
          final fade = t < 0.8 ? 1.0 : (1 - t) / 0.2;

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.55 * fade),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < _cardCount; i++) _card(i, t),
                  Positioned(
                    bottom: 40,
                    child: Text(
                      t < 0.55 ? 'Shuffling...' : 'Dealing...',
                      style: AppTextStyles.h4.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(int i, double t) {
    final phase = i / _cardCount;

    // Phase one: cards splay apart and riffle back together.
    // Phase two: they fan out as if being dealt around the table.
    final shuffle = math.sin((t * 3.2 + phase) * math.pi * 2);
    final dealing = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

    final spreadX = shuffle * 42 * (1 - dealing);
    final spreadY = math.cos((t * 2.6 + phase) * math.pi * 2) * 14 * (1 - dealing);

    final dealAngle = (i - (_cardCount - 1) / 2) * 0.34;
    final dealX = math.sin(dealAngle) * 150 * dealing;
    final dealY = -math.cos(dealAngle) * 40 * dealing + 30 * dealing;

    return Transform.translate(
      offset: Offset(spreadX + dealX, spreadY + dealY),
      child: Transform.rotate(
        angle: shuffle * 0.16 * (1 - dealing) + dealAngle * dealing,
        child: const CardBackView(width: 58),
      ),
    );
  }
}
