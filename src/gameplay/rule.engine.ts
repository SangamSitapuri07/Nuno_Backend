import {
  Card,
  CardColor,
  CardType,
  CardValue,
  GameDirection,
  MatchState,
} from './game.types';

export class RuleEngine {

  // ─────────────────────────────────────────
  // VALIDATE CARD PLAY
  // ─────────────────────────────────────────

  isValidPlay(card: Card, state: MatchState): boolean {
    // Wild cards are always valid
    if (card.type === CardType.WILD) return true;

    // Match current color
    if (card.color === state.currentColor) return true;

    // Match current value
    if (card.value === state.currentValue) return true;

    return false;
  }

  // ─────────────────────────────────────────
  // VALIDATE PLAYER OWNS CARD
  // ─────────────────────────────────────────

  playerOwnsCard(userId: string, cardId: string, state: MatchState): boolean {
    const hand = state.hands[userId];
    if (!hand) return false;
    return hand.some((c) => c.cardId === cardId);
  }

  // ─────────────────────────────────────────
  // IS PLAYER TURN
  // ─────────────────────────────────────────

  isPlayerTurn(userId: string, state: MatchState): boolean {
    return state.currentTurn === userId;
  }

  // ─────────────────────────────────────────
  // GET NEXT PLAYER
  // ─────────────────────────────────────────

  getNextPlayer(
    currentPlayerId: string,
    players: string[],
    direction: GameDirection,
    skip: boolean = false
  ): string {
    const currentIndex = players.indexOf(currentPlayerId);
    const totalPlayers = players.length;
    let nextIndex: number;

    if (direction === GameDirection.CLOCKWISE) {
      nextIndex = (currentIndex + 1) % totalPlayers;
      if (skip) {
        nextIndex = (currentIndex + 2) % totalPlayers;
      }
    } else {
      nextIndex = (currentIndex - 1 + totalPlayers) % totalPlayers;
      if (skip) {
        nextIndex = (currentIndex - 2 + totalPlayers) % totalPlayers;
      }
    }

    return players[nextIndex];
  }

  // ─────────────────────────────────────────
  // TOGGLE DIRECTION
  // ─────────────────────────────────────────

  toggleDirection(direction: GameDirection): GameDirection {
    return direction === GameDirection.CLOCKWISE
      ? GameDirection.COUNTER_CLOCKWISE
      : GameDirection.CLOCKWISE;
  }

  // ─────────────────────────────────────────
  // CHECK WIN
  // ─────────────────────────────────────────

  checkWin(userId: string, state: MatchState): boolean {
    const hand = state.hands[userId];
    if (!hand) return false;
    return hand.length === 0;
  }

  // ─────────────────────────────────────────
  // VALIDATE WILD COLOR
  // ─────────────────────────────────────────

  isValidColor(color: CardColor): boolean {
    return [
      CardColor.RED,
      CardColor.BLUE,
      CardColor.GREEN,
      CardColor.YELLOW,
    ].includes(color);
  }

  // ─────────────────────────────────────────
  // GET CARD FROM HAND
  // ─────────────────────────────────────────

  getCardFromHand(
    userId: string,
    cardId: string,
    state: MatchState
  ): Card | null {
    const hand = state.hands[userId];
    if (!hand) return null;
    return hand.find((c) => c.cardId === cardId) || null;
  }

  // ─────────────────────────────────────────
  // REMOVE CARD FROM HAND
  // ─────────────────────────────────────────

  removeCardFromHand(
    userId: string,
    cardId: string,
    state: MatchState
  ): void {
    const hand = state.hands[userId];
    if (!hand) return;
    state.hands[userId] = hand.filter((c) => c.cardId !== cardId);
  }

  // ─────────────────────────────────────────
  // HAS PLAYABLE CARD
  // ─────────────────────────────────────────

  hasPlayableCard(userId: string, state: MatchState): boolean {
    const hand = state.hands[userId];
    if (!hand) return false;
    return hand.some((card) => this.isValidPlay(card, state));
  }
}

export default new RuleEngine();