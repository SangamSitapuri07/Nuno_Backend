import { v4 as uuidv4 } from 'uuid';
import deckEngine from './deck.engine';
import ruleEngine from './rule.engine';
import gameStateManager from './game.state';
import prisma from '../config/database';
import logger from '../utils/logger';
import {
  MatchState,
  MatchStatus,
  GameDirection,
  CardColor,
  CardType,
  CardValue,
  PlayCardInput,
} from './game.types';

const TURN_TIMER_SECONDS = 20;

export class GameEngine {

  async initializeMatch(
    matchId: string,
    roomId: string,
    playerIds: string[],
    gameMode: string
  ): Promise<MatchState> {
    const deck = deckEngine.generateDeck();
    const shuffledDeck = deckEngine.shuffleDeck(deck);

    const { hands, remainingDeck } = deckEngine.dealCards(shuffledDeck, playerIds);

    const { card: startingCard, remainingDeck: drawPile } =
      deckEngine.getStartingCard(remainingDeck);

    const firstPlayer = playerIds[Math.floor(Math.random() * playerIds.length)];

    const state: MatchState = {
      matchId,
      roomId,
      players: playerIds,
      currentTurn: firstPlayer,
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
      unoCalledBy: [],
      lastWildDrawFourChallengeable: false,
    };

    // Save player match mapping in Redis for reconnection
    const redis = (await import('../config/redis')).default;
    for (const playerId of playerIds) {
      await redis.set(`match:player:${playerId}`, matchId, { EX: 3600 });
      await redis.set(`player:room:${playerId}`, roomId, { EX: 3600 });
    }

    await gameStateManager.saveState(state);

    logger.info('Match initialized', {
      matchId,
      playerCount: playerIds.length,
      firstPlayer,
    });

    return state;
  }

  async playCard(
    matchId: string,
    userId: string,
    input: PlayCardInput
  ): Promise<{ state: MatchState; events: string[] }> {
    const state = await gameStateManager.getState(matchId);
    if (!state) {
      throw { code: 'INVALID_MATCH', message: 'Match not found.', status: 404 };
    }

    if (state.status !== MatchStatus.RUNNING) {
      throw { code: 'INVALID_MATCH', message: 'Match is not active.', status: 400 };
    }

    if (!ruleEngine.isPlayerTurn(userId, state)) {
      throw { code: 'INVALID_TURN', message: 'Not your turn.', status: 400 };
    }

    if (!ruleEngine.playerOwnsCard(userId, input.cardId, state)) {
      throw { code: 'INVALID_CARD', message: 'Card not in hand.', status: 400 };
    }

    const card = ruleEngine.getCardFromHand(userId, input.cardId, state);
    if (!card) {
      throw { code: 'INVALID_CARD', message: 'Card not found.', status: 400 };
    }

    if (!ruleEngine.isValidPlay(card, state)) {
      throw { code: 'INVALID_CARD', message: 'Invalid move.', status: 400 };
    }

    if (card.type === CardType.WILD && input.selectedColor) {
      if (!ruleEngine.isValidColor(input.selectedColor)) {
        throw { code: 'INVALID_CARD', message: 'Invalid color selection.', status: 400 };
      }
    }

    const events: string[] = [];

    ruleEngine.removeCardFromHand(userId, input.cardId, state);
    state.discardPile.push(card);
    state.currentValue = card.value;
    state.totalTurns++;

    await this.processCardEffect(card, state, input.selectedColor, events);

    // Reset UNO call if player is no longer on 1 card
    if (state.hands[userId].length !== 1 && state.unoCalledBy) {
      state.unoCalledBy = state.unoCalledBy.filter(id => id !== userId);
    }

    // Track Wild Draw Four for challenge
    if (card.value === CardValue.WILD_DRAW_FOUR) {
      state.lastWildDrawFourBy = userId;
      state.lastWildDrawFourChallengeable = true;
    } else {
      state.lastWildDrawFourChallengeable = false;
    }

    if (ruleEngine.checkWin(userId, state)) {
      state.winner = userId;
      state.status = MatchStatus.FINISHED;
      events.push('game.finished');
      await this.finalizeMatch(state);
    }

    await gameStateManager.saveState(state);

    return { state, events };
  }

  async drawCard(
    matchId: string,
    userId: string,
    count: number = 1
  ): Promise<{ state: MatchState; drawnCards: any[] }> {
    const state = await gameStateManager.getState(matchId);
    if (!state) {
      throw { code: 'INVALID_MATCH', message: 'Match not found.', status: 404 };
    }

    if (!ruleEngine.isPlayerTurn(userId, state)) {
      throw { code: 'INVALID_TURN', message: 'Not your turn.', status: 400 };
    }

    const drawnCards = [];

    for (let i = 0; i < count; i++) {
      if (state.drawPile.length === 0) {
        const { newDrawPile, newDiscardPile } =
          deckEngine.rebuildDrawPile(state.discardPile);
        state.drawPile = newDrawPile;
        state.discardPile = newDiscardPile;
      }

      if (state.drawPile.length > 0) {
        const card = state.drawPile.shift()!;
        state.hands[userId].push(card);
        drawnCards.push(card);
      }
    }

    // Check if drawn card is playable
    const lastDrawnCard = drawnCards[drawnCards.length - 1];
    const canPlayDrawn = lastDrawnCard && ruleEngine.isValidPlay(lastDrawnCard, state);

    if (!canPlayDrawn) {
      state.currentTurn = ruleEngine.getNextPlayer(
        userId,
        state.players,
        state.direction
      );
      state.timerStarted = Date.now();
    }

    await gameStateManager.saveState(state);

    return { state, drawnCards };
  }

  private async processCardEffect(
    card: any,
    state: MatchState,
    selectedColor: CardColor | undefined,
    events: string[]
  ): Promise<void> {
    switch (card.value) {
      case CardValue.SKIP:
        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction, true
        );
        events.push('turn.skipped');
        break;

      case CardValue.REVERSE:
        state.direction = ruleEngine.toggleDirection(state.direction);
        events.push('direction.changed');

        if (state.players.length === 2) {
          state.currentTurn = ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction, true
          );
        } else {
          state.currentTurn = ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction
          );
        }
        break;

      case CardValue.DRAW_TWO:
        const nextPlayerDrawTwo = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction
        );

        for (let i = 0; i < 2; i++) {
          if (state.drawPile.length === 0) {
            const { newDrawPile, newDiscardPile } =
              deckEngine.rebuildDrawPile(state.discardPile);
            state.drawPile = newDrawPile;
            state.discardPile = newDiscardPile;
          }
          if (state.drawPile.length > 0) {
            state.hands[nextPlayerDrawTwo].push(state.drawPile.shift()!);
          }
        }

        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction, true
        );
        break;

      case CardValue.WILD:
        if (selectedColor) state.currentColor = selectedColor;
        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction
        );
        break;

      case CardValue.WILD_DRAW_FOUR:
        if (selectedColor) state.currentColor = selectedColor;

        const nextPlayerWildFour = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction
        );

        for (let i = 0; i < 4; i++) {
          if (state.drawPile.length === 0) {
            const { newDrawPile, newDiscardPile } =
              deckEngine.rebuildDrawPile(state.discardPile);
            state.drawPile = newDrawPile;
            state.discardPile = newDiscardPile;
          }
          if (state.drawPile.length > 0) {
            state.hands[nextPlayerWildFour].push(state.drawPile.shift()!);
          }
        }

        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction, true
        );
        break;

      default:
        state.currentColor = card.color;
        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction
        );
        break;
    }

    state.timerStarted = Date.now();
  }

  async handleTimeout(matchId: string): Promise<MatchState | null> {
    const state = await gameStateManager.getState(matchId);
    if (!state || state.status !== MatchStatus.RUNNING) return null;

    const currentPlayer = state.currentTurn;

    // Draw a card
    const hand = state.hands[currentPlayer];
    if (!hand) return null;

    if (state.drawPile.length === 0) {
      const { newDrawPile, newDiscardPile } = deckEngine.rebuildDrawPile(state.discardPile);
      state.drawPile = newDrawPile;
      state.discardPile = newDiscardPile;
    }

    if (state.drawPile.length > 0) {
      const drawnCard = state.drawPile.shift()!;
      state.hands[currentPlayer].push(drawnCard);
    }

    // Force advance turn
    state.currentTurn = ruleEngine.getNextPlayer(
      currentPlayer,
      state.players,
      state.direction
    );
    state.timerStarted = Date.now();

    await gameStateManager.saveState(state);

    logger.info('Auto-drew card and advanced turn', {
      matchId,
      previousPlayer: currentPlayer,
      newTurn: state.currentTurn,
    });

    return state;
  }

  // Check if player has any playable card
  hasPlayableCard(userId: string, state: MatchState): boolean {
    const hand = state.hands[userId];
    if (!hand) return false;
    return hand.some(card => ruleEngine.isValidPlay(card, state));
  }

  private async finalizeMatch(state: MatchState): Promise<void> {
    try {
      const duration = Math.floor((Date.now() - state.startedAt) / 1000);

      const match = await prisma.match.create({
        data: {
          roomId: state.roomId,
          winnerId: state.winner,
          duration,
          gameMode: 'CASUAL' as any,
          totalTurns: state.totalTurns,
          startedAt: new Date(state.startedAt),
          endedAt: new Date(),
        },
      });

      for (let i = 0; i < state.players.length; i++) {
        const playerId = state.players[i];
        const isWinner = playerId === state.winner;
        const xpEarned = isWinner ? 125 : 50;
        const ratingChange = isWinner ? 25 : -15;

        await prisma.matchPlayer.create({
          data: {
            matchId: match.id,
            playerId,
            finalPosition: isWinner ? 1 : i + 1,
            cardsRemaining: state.hands[playerId]?.length || 0,
            ratingChange,
            xpEarned,
          },
        });

        await prisma.playerStatistics.update({
          where: { userId: playerId },
          data: {
            gamesPlayed: { increment: 1 },
            gamesWon: isWinner ? { increment: 1 } : undefined,
            gamesLost: !isWinner ? { increment: 1 } : undefined,
            cardsPlayed: { increment: state.totalTurns },
          },
        });

        await prisma.user.update({
          where: { id: playerId },
          data: {
            xp: { increment: xpEarned },
            coins: { increment: isWinner ? 50 : 20 },
          },
        });

        await prisma.leaderboard.update({
          where: { playerId },
          data: { rating: { increment: ratingChange } },
        });
      }

      // Cleanup player match state
      const redis = (await import('../config/redis')).default;
      for (const playerId of state.players) {
        await redis.del(`match:player:${playerId}`);
        await redis.del(`player:room:${playerId}`);
      }

      logger.info('Match finalized', {
        matchId: state.matchId,
        winner: state.winner,
        duration,
      });

    } catch (error) {
      logger.error('Error finalizing match', { error, matchId: state.matchId });
    }
  }

  async getMatchState(matchId: string): Promise<MatchState | null> {
    return await gameStateManager.getState(matchId);
  }
}

export default new GameEngine();