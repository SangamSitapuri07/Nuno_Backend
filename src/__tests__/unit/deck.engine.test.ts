import deckEngine from '../../gameplay/deck.engine';
import { CardType, CardColor, CardValue } from '../../gameplay/game.types';

describe('DeckEngine', () => {

  describe('generateDeck', () => {
    it('should generate 108 cards', () => {
      const deck = deckEngine.generateDeck();
      expect(deck).toHaveLength(108);
    });

    it('should contain 4 wild cards', () => {
      const deck = deckEngine.generateDeck();
      const wilds = deck.filter(
        (c) => c.value === CardValue.WILD
      );
      expect(wilds).toHaveLength(4);
    });

    it('should contain 4 wild draw four cards', () => {
      const deck = deckEngine.generateDeck();
      const wildDrawFours = deck.filter(
        (c) => c.value === CardValue.WILD_DRAW_FOUR
      );
      expect(wildDrawFours).toHaveLength(4);
    });

    it('should contain unique card IDs', () => {
      const deck = deckEngine.generateDeck();
      const ids = deck.map((c) => c.cardId);
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).toBe(deck.length);
    });

    it('should contain cards of all four colors', () => {
      const deck = deckEngine.generateDeck();
      const colors = new Set(
        deck
          .filter((c) => c.type !== CardType.WILD)
          .map((c) => c.color)
      );
      expect(colors.has(CardColor.RED)).toBe(true);
      expect(colors.has(CardColor.BLUE)).toBe(true);
      expect(colors.has(CardColor.GREEN)).toBe(true);
      expect(colors.has(CardColor.YELLOW)).toBe(true);
    });
  });

  describe('shuffleDeck', () => {
    it('should return same number of cards', () => {
      const deck = deckEngine.generateDeck();
      const shuffled = deckEngine.shuffleDeck(deck);
      expect(shuffled).toHaveLength(deck.length);
    });

    it('should contain same cards after shuffle', () => {
      const deck = deckEngine.generateDeck();
      const shuffled = deckEngine.shuffleDeck(deck);
      const originalIds = new Set(deck.map((c) => c.cardId));
      const shuffledIds = new Set(shuffled.map((c) => c.cardId));
      expect(originalIds).toEqual(shuffledIds);
    });
  });

  describe('dealCards', () => {
    it('should deal 7 cards to each player', () => {
      const deck = deckEngine.generateDeck();
      const shuffled = deckEngine.shuffleDeck(deck);
      const playerIds = ['player1', 'player2', 'player3'];
      const { hands } = deckEngine.dealCards(shuffled, playerIds);

      for (const playerId of playerIds) {
        expect(hands[playerId]).toHaveLength(7);
      }
    });

    it('should return remaining deck after dealing', () => {
      const deck = deckEngine.generateDeck();
      const shuffled = deckEngine.shuffleDeck(deck);
      const playerIds = ['player1', 'player2'];
      const { remainingDeck } = deckEngine.dealCards(shuffled, playerIds);
      expect(remainingDeck).toHaveLength(108 - 14);
    });
  });

  describe('getStartingCard', () => {
    it('should return a non-wild starting card', () => {
      const deck = deckEngine.generateDeck();
      const shuffled = deckEngine.shuffleDeck(deck);
      const { card } = deckEngine.getStartingCard(shuffled);
      expect(card.type).not.toBe(CardType.WILD);
    });
  });
});