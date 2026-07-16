import { v4 as uuidv4 } from 'uuid';
import { Card, CardColor, CardValue, CardType } from './game.types';

export class DeckEngine {

  // ─────────────────────────────────────────
  // GENERATE DECK
  // ─────────────────────────────────────────

  generateDeck(): Card[] {
    const deck: Card[] = [];
    const colors = [CardColor.RED, CardColor.BLUE, CardColor.GREEN, CardColor.YELLOW];
    const numberValues = [
      CardValue.ZERO,
      CardValue.ONE,
      CardValue.TWO,
      CardValue.THREE,
      CardValue.FOUR,
      CardValue.FIVE,
      CardValue.SIX,
      CardValue.SEVEN,
      CardValue.EIGHT,
      CardValue.NINE,
    ];
    const actionValues = [
      CardValue.SKIP,
      CardValue.REVERSE,
      CardValue.DRAW_TWO,
    ];

    for (const color of colors) {
      // One zero per color
      deck.push(this.createCard(CardType.NUMBER, color, CardValue.ZERO));

      // Two of each number 1-9
      for (const value of numberValues.slice(1)) {
        deck.push(this.createCard(CardType.NUMBER, color, value));
        deck.push(this.createCard(CardType.NUMBER, color, value));
      }

      // Two of each action card per color
      for (const value of actionValues) {
        deck.push(this.createCard(CardType.ACTION, color, value));
        deck.push(this.createCard(CardType.ACTION, color, value));
      }
    }

    // Four wild cards
    for (let i = 0; i < 4; i++) {
      deck.push(this.createCard(CardType.WILD, CardColor.WILD, CardValue.WILD));
    }

    // Four wild draw four cards
    for (let i = 0; i < 4; i++) {
      deck.push(this.createCard(CardType.WILD, CardColor.WILD, CardValue.WILD_DRAW_FOUR));
    }

    return deck;
  }

  // ─────────────────────────────────────────
  // SHUFFLE DECK
  // ─────────────────────────────────────────

  shuffleDeck(deck: Card[]): Card[] {
    const shuffled = [...deck];

    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }

    return shuffled;
  }

  // ─────────────────────────────────────────
  // DEAL CARDS
  // ─────────────────────────────────────────

  dealCards(
    deck: Card[],
    playerIds: string[],
    handSize: number = 7
  ): { hands: { [userId: string]: Card[] }; remainingDeck: Card[] } {
    const hands: { [userId: string]: Card[] } = {};
    let deckIndex = 0;

    for (const playerId of playerIds) {
      hands[playerId] = [];
      for (let i = 0; i < handSize; i++) {
        if (deckIndex < deck.length) {
          hands[playerId].push(deck[deckIndex]);
          deckIndex++;
        }
      }
    }

    const remainingDeck = deck.slice(deckIndex);

    return { hands, remainingDeck };
  }

  // ─────────────────────────────────────────
  // GET STARTING CARD
  // ─────────────────────────────────────────

  getStartingCard(deck: Card[]): { card: Card; remainingDeck: Card[] } {
    let index = 0;

    // Starting card must not be a wild card
    while (index < deck.length) {
      if (deck[index].type !== CardType.WILD) {
        const card = deck[index];
        const remainingDeck = [
          ...deck.slice(0, index),
          ...deck.slice(index + 1),
        ];
        return { card, remainingDeck };
      }
      index++;
    }

    // Fallback
    const card = deck[0];
    const remainingDeck = deck.slice(1);
    return { card, remainingDeck };
  }

  // ─────────────────────────────────────────
  // REBUILD DRAW PILE
  // ─────────────────────────────────────────

  rebuildDrawPile(discardPile: Card[]): {
    newDrawPile: Card[];
    newDiscardPile: Card[];
  } {
    const topCard = discardPile[discardPile.length - 1];
    const cardsToShuffle = discardPile.slice(0, discardPile.length - 1);
    const newDrawPile = this.shuffleDeck(cardsToShuffle);

    return {
      newDrawPile,
      newDiscardPile: [topCard],
    };
  }

  // ─────────────────────────────────────────
  // CREATE CARD
  // ─────────────────────────────────────────

  private createCard(
    type: CardType,
    color: CardColor,
    value: CardValue
  ): Card {
    return {
      cardId: uuidv4(),
      type,
      color,
      value,
    };
  }
}

export default new DeckEngine();