import ruleEngine from '../../gameplay/rule.engine';
import deckEngine from '../../gameplay/deck.engine';
import {
  MatchState,
  MatchStatus,
  GameDirection,
  CardColor,
  CardValue,
  CardType,
} from '../../gameplay/game.types';

const createMockState = (): MatchState => {
  const deck = deckEngine.generateDeck();
  const shuffled = deckEngine.shuffleDeck(deck);
  const playerIds = ['player1', 'player2'];
  const { hands, remainingDeck } = deckEngine.dealCards(shuffled, playerIds);
  const { card: startingCard, remainingDeck: drawPile } =
    deckEngine.getStartingCard(remainingDeck);

  return {
    matchId: 'match1',
    roomId: 'room1',
    players: playerIds,
    currentTurn: 'player1',
    direction: GameDirection.CLOCKWISE,
    currentColor: startingCard.color,
    currentValue: startingCard.value,
    drawPile,
    discardPile: [startingCard],
    hands,
    status: MatchStatus.RUNNING,
    timerStarted: Date.now(),
    winner: null,
    totalTurns: 0,
    startedAt: Date.now(),
  };
};

describe('RuleEngine', () => {

  describe('isPlayerTurn', () => {
    it('should return true for current player', () => {
      const state = createMockState();
      expect(ruleEngine.isPlayerTurn('player1', state)).toBe(true);
    });

    it('should return false for other player', () => {
      const state = createMockState();
      expect(ruleEngine.isPlayerTurn('player2', state)).toBe(false);
    });
  });

  describe('playerOwnsCard', () => {
    it('should return true if player owns the card', () => {
      const state = createMockState();
      const card = state.hands['player1'][0];
      expect(
        ruleEngine.playerOwnsCard('player1', card.cardId, state)
      ).toBe(true);
    });

    it('should return false if player does not own the card', () => {
      const state = createMockState();
      const card = state.hands['player2'][0];
      expect(
        ruleEngine.playerOwnsCard('player1', card.cardId, state)
      ).toBe(false);
    });
  });

  describe('isValidPlay', () => {
    it('should allow wild card regardless of color', () => {
      const state = createMockState();
      state.currentColor = CardColor.RED;

      const wildCard = {
        cardId: 'wild1',
        type: CardType.WILD,
        color: CardColor.WILD,
        value: CardValue.WILD,
      };

      expect(ruleEngine.isValidPlay(wildCard, state)).toBe(true);
    });

    it('should allow card matching current color', () => {
      const state = createMockState();
      state.currentColor = CardColor.RED;

      const redCard = {
        cardId: 'red1',
        type: CardType.NUMBER,
        color: CardColor.RED,
        value: CardValue.FIVE,
      };

      expect(ruleEngine.isValidPlay(redCard, state)).toBe(true);
    });

    it('should reject card not matching color or value', () => {
      const state = createMockState();
      state.currentColor = CardColor.RED;
      state.currentValue = CardValue.FIVE;

      const blueThree = {
        cardId: 'blue3',
        type: CardType.NUMBER,
        color: CardColor.BLUE,
        value: CardValue.THREE,
      };

      expect(ruleEngine.isValidPlay(blueThree, state)).toBe(false);
    });
  });

  describe('getNextPlayer', () => {
    it('should return next player clockwise', () => {
      const players = ['p1', 'p2', 'p3', 'p4'];
      const next = ruleEngine.getNextPlayer(
        'p1',
        players,
        GameDirection.CLOCKWISE
      );
      expect(next).toBe('p2');
    });

    it('should return next player counter clockwise', () => {
      const players = ['p1', 'p2', 'p3', 'p4'];
      const next = ruleEngine.getNextPlayer(
        'p1',
        players,
        GameDirection.COUNTER_CLOCKWISE
      );
      expect(next).toBe('p4');
    });

    it('should skip player when skip is true', () => {
      const players = ['p1', 'p2', 'p3', 'p4'];
      const next = ruleEngine.getNextPlayer(
        'p1',
        players,
        GameDirection.CLOCKWISE,
        true
      );
      expect(next).toBe('p3');
    });
  });

  describe('checkWin', () => {
    it('should return true when hand is empty', () => {
      const state = createMockState();
      state.hands['player1'] = [];
      expect(ruleEngine.checkWin('player1', state)).toBe(true);
    });

    it('should return false when hand is not empty', () => {
      const state = createMockState();
      expect(ruleEngine.checkWin('player1', state)).toBe(false);
    });
  });

  describe('toggleDirection', () => {
    it('should toggle clockwise to counter clockwise', () => {
      const result = ruleEngine.toggleDirection(GameDirection.CLOCKWISE);
      expect(result).toBe(GameDirection.COUNTER_CLOCKWISE);
    });

    it('should toggle counter clockwise to clockwise', () => {
      const result = ruleEngine.toggleDirection(
        GameDirection.COUNTER_CLOCKWISE
      );
      expect(result).toBe(GameDirection.CLOCKWISE);
    });
  });
});