import 'package:flutter/material.dart';

import 'playing_card.dart';

/// Flies a face-down card from the draw pile down into the player's hand.
///
/// Purely presentational and driven by an overlay, so it neither blocks the
/// tap that started it nor delays the state update the server sends back:
/// without it a drawn card simply appeared in the hand with no indication of
/// where it came from.
class DrawFlight {
  DrawFlight._();

  static const Duration duration = Duration(milliseconds: 460);

  /// Animates from [from] to [to], both in global coordinates.
  static void play(
    BuildContext context, {
    required Offset from,
    required Offset to,
    double width = 62,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: duration,
    );

    final curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: curve,
        builder: (_, __) {
          final t = curve.value;

          // Slight arc: the card lifts off the pile before dropping into the
          // hand, which reads far better than a straight slide.
          final position = Offset.lerp(from, to, t)! -
              Offset(0, _arc(t) * 46);

          return Positioned(
            left: position.dx,
            top: position.dy,
            child: IgnorePointer(
              child: Opacity(
                // Fades out just at the end, so it hands off to the real card
                // rather than visibly stopping.
                opacity: t < 0.86 ? 1 : (1 - t) / 0.14,
                child: Transform.rotate(
                  angle: t * 0.6,
                  child: Transform.scale(
                    scale: 1 - 0.18 * t,
                    child: CardBackView(width: width),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    overlay.insert(entry);
    controller.forward().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }

  /// 0 at both ends, 1 in the middle.
  static double _arc(double t) => 4 * t * (1 - t);
}
