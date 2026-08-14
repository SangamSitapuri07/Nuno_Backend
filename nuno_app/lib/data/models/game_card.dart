import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json.dart';

/// Mirrors `Card` in src/gameplay/game.types.ts
class GameCard extends Equatable {
  final String cardId;
  final CardColor color;
  final CardValue value;

  const GameCard({
    required this.cardId,
    required this.color,
    required this.value,
  });

  factory GameCard.fromJson(Map<String, dynamic> json) => GameCard(
        cardId: J.str(json['cardId']),
        color: CardColorX.parse(J.strOrNull(json['color'])),
        value: CardValueX.parse(J.strOrNull(json['value'])),
      );

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'color': color.wire,
        'value': value.wire,
      };

  bool get isWild => color.isWild || value.isWild;

  /// Client-side playability preview mirroring src/gameplay/rule.engine.ts:
  /// a card is playable if it is wild, matches the active colour, or matches
  /// the active value. The server remains the source of truth.
  bool isPlayableOn({
    required CardColor currentColor,
    required CardValue currentValue,
  }) {
    if (isWild) return true;
    if (color == currentColor) return true;
    if (value == currentValue) return true;
    return false;
  }

  @override
  List<Object?> get props => [cardId, color, value];
}
