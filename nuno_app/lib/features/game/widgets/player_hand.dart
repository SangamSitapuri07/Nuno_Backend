import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/game_card.dart';
import 'playing_card.dart';

/// The local player's fanned hand.
///
/// Cards overlap in a shallow arc; the selected card lifts and enlarges.
/// Tapping a playable card selects it, tapping again confirms the play.
class PlayerHand extends StatefulWidget {
  final List<GameCard> cards;
  final bool Function(GameCard) isPlayable;
  final bool isMyTurn;
  final void Function(GameCard) onPlay;
  final String? pendingCardId;

  /// Whether this card may be played out of turn, under the jump-in house
  /// rule. Always false when the rule is off.
  final bool Function(GameCard) canJumpIn;

  const PlayerHand({
    super.key,
    required this.cards,
    required this.isPlayable,
    required this.isMyTurn,
    required this.onPlay,
    required this.canJumpIn,
    this.pendingCardId,
  });

  @override
  State<PlayerHand> createState() => _PlayerHandState();
}

class _PlayerHandState extends State<PlayerHand> {
  String? _selectedId;

  @override
  void didUpdateWidget(covariant PlayerHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop the selection if that card left the hand.
    if (_selectedId != null &&
        !widget.cards.any((c) => c.cardId == _selectedId)) {
      _selectedId = null;
    }
    // Keep a selection alive when it is jump-in-able, otherwise the card the
    // player is lining up vanishes from under them the moment the turn moves.
    if (!widget.isMyTurn &&
        _selectedId != null &&
        !widget.cards.any(
          (c) => c.cardId == _selectedId && widget.canJumpIn(c),
        )) {
      _selectedId = null;
    }
  }

  void _onTap(GameCard card) {
    // A jump-in is legal precisely when it is NOT your turn, so the turn
    // check cannot be the only gate.
    final allowed = widget.isMyTurn
        ? widget.isPlayable(card)
        : widget.canJumpIn(card);

    if (!allowed) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_selectedId == card.cardId) {
      HapticFeedback.mediumImpact();
      widget.onPlay(card);
      setState(() => _selectedId = null);
    } else {
      HapticFeedback.selectionClick();
      setState(() => _selectedId = card.cardId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return SizedBox(
        height: AppDimens.handCardHeight * 0.8,
        child: Center(
          child: Text('No cards left', style: AppTextStyles.bodySm),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    const cardWidth = AppDimens.handCardWidth;
    const cardHeight = AppDimens.handCardHeight;

    // Overlap so the whole hand fits, down to a readable minimum.
    final available = screenWidth - AppDimens.xxl;
    final count = widget.cards.length;
    final rawStep = count > 1 ? (available - cardWidth) / (count - 1) : 0.0;
    final double step = rawStep.clamp(34.0, cardWidth * 0.88).toDouble();
    final double totalWidth = cardWidth + step * (count - 1);
    final needsScroll = totalWidth > available;

    final stack = SizedBox(
      width: math.max(totalWidth, available),
      height: cardHeight + 34,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            _buildCard(i, count, step, totalWidth, available),
        ],
      ),
    );

    // Clipped either way: the arc lifts cards above their box and a selected
    // card lifts further still, which would otherwise paint outside and trip
    // the overflow indicator.
    if (!needsScroll) return ClipRect(child: stack);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      child: stack,
    );
  }

  Widget _buildCard(
    int i,
    int count,
    double step,
    double totalWidth,
    double available,
  ) {
    final card = widget.cards[i];
    final isSelected = _selectedId == card.cardId;
    final playable = widget.isMyTurn
        ? widget.isPlayable(card)
        : widget.canJumpIn(card);
    final isPending = widget.pendingCardId == card.cardId;

    // Arc: middle cards sit slightly higher, edges tilt outward.
    final centre = (count - 1) / 2;
    final offsetFromCentre = count == 1 ? 0.0 : (i - centre) / centre;
    final angle = offsetFromCentre * 0.055;
    final arcLift = -math.cos(offsetFromCentre * math.pi / 2) * 5;

    final left = (math.max(totalWidth, available) - totalWidth) / 2 + i * step;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: left,
      bottom: (isSelected ? 34 : 0) - arcLift,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isPending ? 0.4 : 1,
        child: Transform.rotate(
          angle: isSelected ? 0 : angle,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            scale: isSelected ? 1.12 : 1,
            child: PlayingCardView(
              card: card,
              width: AppDimens.handCardWidth,
              isPlayable: playable,
              isSelected: isSelected,
              onTap: isPending ? null : () => _onTap(card),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fan of face-down cards representing an opponent's hand (used on wide seats).
class OpponentCardFan extends StatelessWidget {
  final int count;
  final double cardWidth;

  const OpponentCardFan({
    super.key,
    required this.count,
    this.cardWidth = AppDimens.miniCardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final visible = math.min(count, 5);
    const step = 9.0;

    return SizedBox(
      width: cardWidth + step * (visible - 1),
      height: cardWidth / 0.68,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * step,
              child: Transform.rotate(
                angle: (i - (visible - 1) / 2) * 0.08,
                child: CardBackView(width: cardWidth),
              ),
            ),
        ],
      ),
    );
  }
}
