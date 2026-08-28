import { v4 as uuidv4 } from 'uuid';
import deckEngine from './deck.engine';
import ruleEngine from './rule.engine';
import gameStateManager from './game.state';
import prisma from '../config/database';
import logger from '../utils/logger';
import { levelForXp, rewardBetween } from '../users/leveling';
import {
  HouseRules,
  OFFICIAL_RULES,
  MAX_STACK_DRAW,
  describeHouseRules,
} from './house.rules';
import leaderboardService from '../leaderboard/leaderboard.service';
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
    gameMode: string,
    houseRules: HouseRules = OFFICIAL_RULES
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
      cardsPlayedBy: {},
      cardsDrawnBy: {},
      startedAt: Date.now(),
      unoCalledBy: [],
      lastWildDrawFourChallengeable: false,
      houseRules,
      pendingDraw: 0,
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
      rules: describeHouseRules(houseRules),
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

    state.cardsPlayedBy ??= {};
    state.cardsPlayedBy[userId] = (state.cardsPlayedBy[userId] ?? 0) + 1;

    await this.processCardEffect(
      card, state, input.selectedColor, events, input.swapWith
    );

    // Reset UNO call if player is no longer on 1 card
    if (state.hands[userId].length !== 1 && state.unoCalledBy) {
      state.unoCalledBy = state.unoCalledBy.filter(id => id !== userId);
    }

    // Caught not saying it. Officially another player has to notice and
    // challenge; this house rule does the noticing automatically.
    //
    // Checked after the effect has resolved, and only when the player is
    // actually left holding one card - going out entirely is a win, not an
    // offence.
    if (
      state.houseRules?.forceUnoPenalty &&
      state.hands[userId].length === 1 &&
      !(state.unoCalledBy ?? []).includes(userId)
    ) {
      this.dealTo(userId, 2, state);
      events.push('uno.penalty');
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

  /**
   * Plays an identical card out of turn, under the jump-in house rule.
   *
   * The turn is handed to the jumping player before the effect resolves, so
   * play continues from their seat - that is the whole point of the rule.
   */
  async jumpIn(
    matchId: string,
    userId: string,
    input: PlayCardInput
  ): Promise<{ state: MatchState; events: string[] }> {
    const state = await gameStateManager.getState(matchId);
    if (!state) {
      throw { code: 'INVALID_MATCH', message: 'Match not found.', status: 404 };
    }

    if (!state.houseRules?.jumpIn) {
      throw {
        code: 'RULE_DISABLED',
        message: 'Jump-in is not enabled for this game.',
        status: 400,
      };
    }

    if (state.status !== MatchStatus.RUNNING) {
      throw { code: 'INVALID_MATCH', message: 'Match is not active.', status: 400 };
    }

    if (!state.players.includes(userId)) {
      throw { code: 'INVALID_MATCH', message: 'Not in this match.', status: 400 };
    }

    const card = ruleEngine.getCardFromHand(userId, input.cardId, state);
    if (!card) {
      throw { code: 'INVALID_CARD', message: 'Card not found.', status: 400 };
    }

    if (!ruleEngine.canJumpIn(card, userId, state)) {
      throw {
        code: 'INVALID_CARD',
        message: 'That card cannot be jumped in.',
        status: 400,
      };
    }

    // Seat the jumper first; processCardEffect advances from currentTurn.
    state.currentTurn = userId;

    const events: string[] = ['card.jumpedIn'];

    ruleEngine.removeCardFromHand(userId, input.cardId, state);
    state.discardPile.push(card);
    state.currentValue = card.value;
    state.totalTurns++;

    state.cardsPlayedBy ??= {};
    state.cardsPlayedBy[userId] = (state.cardsPlayedBy[userId] ?? 0) + 1;

    await this.processCardEffect(
      card, state, input.selectedColor, events, input.swapWith
    );

    if (state.hands[userId].length !== 1 && state.unoCalledBy) {
      state.unoCalledBy = state.unoCalledBy.filter((id) => id !== userId);
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

    // Taking a stacked penalty. The player could not - or chose not to -
    // answer it, so they take the lot and the turn moves on regardless of
    // what they happened to draw.
    const takingStack = (state.pendingDraw ?? 0) > 0;
    if (takingStack) {
      count = state.pendingDraw!;
    }

    const drawOne = (): boolean => {
      if (state.drawPile.length === 0) {
        const { newDrawPile, newDiscardPile } =
          deckEngine.rebuildDrawPile(state.discardPile);
        state.drawPile = newDrawPile;
        state.discardPile = newDiscardPile;
      }
      if (state.drawPile.length === 0) return false;

      const card = state.drawPile.shift()!;
      state.hands[userId].push(card);
      drawnCards.push(card);

      state.cardsDrawnBy ??= {};
      state.cardsDrawnBy[userId] = (state.cardsDrawnBy[userId] ?? 0) + 1;
      return true;
    };

    if (!takingStack && state.houseRules?.drawToMatch) {
      // Keep going until something playable turns up. Bounded by the size of
      // a full deck so an unplayable state cannot loop for ever.
      let guard = 108;
      while (guard-- > 0) {
        if (!drawOne()) break;
        if (ruleEngine.isValidPlay(drawnCards[drawnCards.length - 1], state)) {
          break;
        }
      }
    } else {
      for (let i = 0; i < count; i++) {
        if (!drawOne()) break;
      }
    }

    if (takingStack) {
      state.pendingDraw = 0;
      state.pendingDrawType = undefined;
    }

    // Check if drawn card is playable
    const lastDrawnCard = drawnCards[drawnCards.length - 1];
    const canPlayDrawn =
      !takingStack &&
      lastDrawnCard &&
      ruleEngine.isValidPlay(lastDrawnCard, state);

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

  // ─────────────────────────────────────────
  // HOUSE-RULE HELPERS
  // ─────────────────────────────────────────

  /** Moves [count] cards from the draw pile into a player's hand. */
  private dealTo(playerId: string, count: number, state: MatchState): void {
    for (let i = 0; i < count; i++) {
      if (state.drawPile.length === 0) {
        const { newDrawPile, newDiscardPile } =
          deckEngine.rebuildDrawPile(state.discardPile);
        state.drawPile = newDrawPile;
        state.discardPile = newDiscardPile;
      }
      // The pile can still be empty if the discard had nothing to recycle.
      if (state.drawPile.length === 0) return;
      state.hands[playerId].push(state.drawPile.shift()!);
    }
  }

  /**
   * Seven: swap hands with a chosen player.
   *
   * An invalid or missing target is a no-op rather than an error - the seven
   * is still a perfectly good number card, and rejecting the play outright
   * would strand a client that did not send a target.
   */
  private swapHands(
    playerId: string,
    targetId: string | undefined,
    state: MatchState,
    events: string[]
  ): void {
    if (!targetId || targetId === playerId) return;
    if (!state.players.includes(targetId)) return;

    const mine = state.hands[playerId];
    state.hands[playerId] = state.hands[targetId];
    state.hands[targetId] = mine;

    // Either player may now be on one card, or no longer on one, so the
    // outstanding UNO calls no longer describe the table.
    state.unoCalledBy = (state.unoCalledBy ?? []).filter(
      (id) => id !== playerId && id !== targetId
    );

    events.push('hands.swapped');
  }

  /** Zero: every hand moves one seat in the current direction of play. */
  private rotateHands(state: MatchState, events: string[]): void {
    const order = state.players;
    if (order.length < 2) return;

    const hands = order.map((id) => state.hands[id]);

    if (state.direction === GameDirection.CLOCKWISE) {
      // Each player receives the hand of the player before them.
      for (let i = 0; i < order.length; i++) {
        state.hands[order[i]] = hands[(i - 1 + order.length) % order.length];
      }
    } else {
      for (let i = 0; i < order.length; i++) {
        state.hands[order[i]] = hands[(i + 1) % order.length];
      }
    }

    // Nobody's call survives a rotation.
    state.unoCalledBy = [];
    events.push('hands.rotated');
  }

  private async processCardEffect(
    card: any,
    state: MatchState,
    selectedColor: CardColor | undefined,
    events: string[],
    swapWith?: string
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
        state.currentColor = card.color;

        if (state.houseRules?.stackDrawTwo) {
          // Hand the growing penalty to the next player and let them answer
          // it. They draw only when they cannot, which is handled in
          // resolvePendingDraw.
          state.pendingDraw = Math.min(
            (state.pendingDraw ?? 0) + 2,
            MAX_STACK_DRAW
          );
          state.pendingDrawType = CardValue.DRAW_TWO;
          state.currentTurn = ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction
          );
          events.push('draw.stacked');
          break;
        }

        this.dealTo(
          ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction
          ),
          2,
          state
        );

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

        if (state.houseRules?.stackDrawFour) {
          state.pendingDraw = Math.min(
            (state.pendingDraw ?? 0) + 4,
            MAX_STACK_DRAW
          );
          state.pendingDrawType = CardValue.WILD_DRAW_FOUR;
          state.currentTurn = ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction
          );
          events.push('draw.stacked');
          break;
        }

        this.dealTo(
          ruleEngine.getNextPlayer(
            state.currentTurn, state.players, state.direction
          ),
          4,
          state
        );

        state.currentTurn = ruleEngine.getNextPlayer(
          state.currentTurn, state.players, state.direction, true
        );
        break;

      default:
        state.currentColor = card.color;

        if (state.houseRules?.sevenZero) {
          if (card.value === CardValue.SEVEN) {
            this.swapHands(state.currentTurn, swapWith, state, events);
          } else if (card.value === CardValue.ZERO) {
            this.rotateHands(state, events);
          }
        }

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

        // Streaks and the win rate were never maintained, so the profile
        // showed zeroes however much you played. Read the row first so both
        // can be derived rather than blindly incremented.
        const before = await prisma.playerStatistics.findUnique({
          where: { userId: playerId },
        });

        const gamesPlayed = (before?.gamesPlayed ?? 0) + 1;
        const gamesWon = (before?.gamesWon ?? 0) + (isWinner ? 1 : 0);
        const currentWinStreak = isWinner
          ? (before?.currentWinStreak ?? 0) + 1
          : 0;
        const longestWinStreak = Math.max(
          before?.longestWinStreak ?? 0,
          currentWinStreak
        );

        await prisma.playerStatistics.upsert({
          where: { userId: playerId },
          // A row is created at signup, but an account that predates that -
          // or one whose row was lost - would otherwise throw here and abort
          // the whole finalisation, losing everyone's xp for the match.
          create: {
            userId: playerId,
            gamesPlayed: 1,
            gamesWon: isWinner ? 1 : 0,
            gamesLost: isWinner ? 0 : 1,
            winRate: isWinner ? 100 : 0,
            currentWinStreak,
            longestWinStreak,
            cardsPlayed: state.cardsPlayedBy?.[playerId] ?? 0,
            cardsDrawn: state.cardsDrawnBy?.[playerId] ?? 0,
          },
          update: {
            gamesPlayed: { increment: 1 },
            gamesWon: isWinner ? { increment: 1 } : undefined,
            gamesLost: !isWinner ? { increment: 1 } : undefined,
            winRate: Math.round((gamesWon / gamesPlayed) * 1000) / 10,
            currentWinStreak,
            longestWinStreak,
            // Per player, not the match-wide turn count that used to be
            // credited identically to everyone at the table.
            cardsPlayed: { increment: state.cardsPlayedBy?.[playerId] ?? 0 },
            cardsDrawn: { increment: state.cardsDrawnBy?.[playerId] ?? 0 },
          },
        });

        // Award the level that the new xp total earns, plus its coins. The
        // level column existed but nothing ever recalculated it, so every
        // account stayed at 1 no matter how much xp it accumulated.
        const player = await prisma.user.findUnique({
          where: { id: playerId },
          select: { xp: true, level: true },
        });

        const newXp = (player?.xp ?? 0) + xpEarned;
        const oldLevel = player?.level ?? 1;
        const newLevel = levelForXp(newXp);
        const levelCoins = rewardBetween(oldLevel, newLevel);

        await prisma.user.update({
          where: { id: playerId },
          data: {
            xp: newXp,
            level: newLevel,
            coins: { increment: (isWinner ? 50 : 20) + levelCoins },
          },
        });

        if (newLevel > oldLevel) {
          await prisma.notification.create({
            data: {
              playerId,
              title: `Level ${newLevel}`,
              message: `You reached level ${newLevel} and earned ${levelCoins} coins.`,
            },
          });
          logger.info('Player levelled up', {
            playerId,
            from: oldLevel,
            to: newLevel,
            coins: levelCoins,
          });
        }

        // Rewrite tier and division alongside the rating.
        //
        // Only `rating` used to be written, so the tier stayed at whatever
        // the row was created with - BRONZE III, the schema default - no
        // matter how high the rating climbed. That is why a 1020-rated
        // player was labelled "Bronze III" while GOLD starts at 1000.
        // Reading the row first also stops the rating going negative, which
        // `increment` on its own allowed.
        const row = await prisma.leaderboard.findUnique({
          where: { playerId },
          select: { rating: true },
        });

        const newRating = Math.max(0, (row?.rating ?? 1000) + ratingChange);
        const { tier, division } = leaderboardService.getTierFromRating(newRating);

        await prisma.leaderboard.update({
          where: { playerId },
          data: { rating: newRating, tier, division },
        });
      }

      // Clear the match mapping, but NOT the room membership.
      //
      // Deleting `player:room:` here evicted everyone from their own lobby
      // the instant the game ended, which is the moment they are being asked
      // whether they want to play again. The room is what the rematch vote
      // and the results screen both belong to, so it outlives the match and
      // is released when the player actually leaves - see room.leave and the
      // disconnect handler.
      const redis = (await import('../config/redis')).default;
      for (const playerId of state.players) {
        await redis.del(`match:player:${playerId}`);
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