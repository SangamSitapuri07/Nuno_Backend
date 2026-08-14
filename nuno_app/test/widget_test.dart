import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nuno_app/data/models/enums.dart';
import 'package:nuno_app/data/models/game_card.dart';
import 'package:nuno_app/main.dart';

void main() {
  group('Card playability (mirrors src/gameplay/rule.engine.ts)', () {
    const red5 = GameCard(
      cardId: 'a',
      color: CardColor.red,
      value: CardValue.five,
    );
    const blue5 = GameCard(
      cardId: 'b',
      color: CardColor.blue,
      value: CardValue.five,
    );
    const blue9 = GameCard(
      cardId: 'c',
      color: CardColor.blue,
      value: CardValue.nine,
    );
    const wild = GameCard(
      cardId: 'd',
      color: CardColor.wild,
      value: CardValue.wild,
    );

    test('matches on colour', () {
      expect(
        red5.isPlayableOn(
          currentColor: CardColor.red,
          currentValue: CardValue.nine,
        ),
        isTrue,
      );
    });

    test('matches on value', () {
      expect(
        blue5.isPlayableOn(
          currentColor: CardColor.red,
          currentValue: CardValue.five,
        ),
        isTrue,
      );
    });

    test('wild is always playable', () {
      expect(
        wild.isPlayableOn(
          currentColor: CardColor.green,
          currentValue: CardValue.two,
        ),
        isTrue,
      );
    });

    test('rejects when neither colour nor value match', () {
      expect(
        blue9.isPlayableOn(
          currentColor: CardColor.red,
          currentValue: CardValue.five,
        ),
        isFalse,
      );
    });
  });

  group('Wire formats match the backend enums', () {
    test('card values serialise correctly', () {
      expect(CardValue.drawTwo.wire, 'DRAW_TWO');
      expect(CardValue.wildDrawFour.wire, 'WILD_DRAW_FOUR');
      expect(CardValue.zero.wire, '0');
    });

    test('parsing is tolerant of unknown values', () {
      expect(CardColorX.parse('RED'), CardColor.red);
      expect(CardColorX.parse('nonsense'), CardColor.wild);
      expect(GameModeX.parse(null), GameMode.casual);
    });
  });

  testWidgets('App boots to the splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NunoApp()));
    await tester.pump();
    expect(find.byType(NunoApp), findsOneWidget);
  });
}
