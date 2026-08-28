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
    // A stack is pending: the only legal answer is the same draw card.
    //
    // Same type only. A Draw Two chain cannot be answered with a Wild Draw
    // Four and vice versa - that is how virtually every group that plays
    // stacking plays it, and mixing them is rejected even in casual play.
    if (state.pendingDraw && state.pendingDraw > 0) {
      return card.value === state.pendingDrawType;
    }

    // Wild cards are always valid
    if (card.type === CardType.WILD) return true;

    // Match current color
    if (card.color === state.currentColor) return true;

    // Match current value
    if (card.value === state.currentValue) return true;

    return false;
  }

  // ─────────────────────────────────────────
  // JUMP-IN
  // ─────────────────────────────────────────

  /**
   * Whether [card] may be played out of turn under the jump-in house rule.
   *
   * Requires an exact match on colour AND value against the top of the
   * discard pile, and only for number cards: allowing it on action cards
   * makes the turn order unresolvable, since the effect would fire from a
   * seat the game is not currently on.
   *
   * Never legal while a draw stack is pending, and never for the player
   * whose turn it already is - that is an ordinary play.
   */
  canJumpIn(card: Card, userId: string, state: MatchState): boolean {
    if (!state.houseRules?.jumpIn) return false;
    if (state.pendingDraw && state.pendingDraw > 0) return false;
    if (state.currentTurn === userId) return false;
    if (card.type !== CardType.NUMBER) return false;

    const top = state.discardPile[state.discardPile.length - 1];
    if (!top) return false;

    return card.color === top.color && card.value === top.value;
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