import { HouseRules } from './house.rules';

export enum CardColor {
  RED = 'RED',
  BLUE = 'BLUE',
  GREEN = 'GREEN',
  YELLOW = 'YELLOW',
  WILD = 'WILD',
}

export enum CardValue {
  ZERO = '0',
  ONE = '1',
  TWO = '2',
  THREE = '3',
  FOUR = '4',
  FIVE = '5',
  SIX = '6',
  SEVEN = '7',
  EIGHT = '8',
  NINE = '9',
  SKIP = 'SKIP',
  REVERSE = 'REVERSE',
  DRAW_TWO = 'DRAW_TWO',
  WILD = 'WILD',
  WILD_DRAW_FOUR = 'WILD_DRAW_FOUR',
}

export enum CardType {
  NUMBER = 'NUMBER',
  ACTION = 'ACTION',
  WILD = 'WILD',
}

export enum GameDirection {
  CLOCKWISE = 'CLOCKWISE',
  COUNTER_CLOCKWISE = 'COUNTER_CLOCKWISE',
}

export enum MatchStatus {
  INITIALIZING = 'INITIALIZING',
  WAITING_FIRST_TURN = 'WAITING_FIRST_TURN',
  RUNNING = 'RUNNING',
  PAUSED = 'PAUSED',
  FINISHED = 'FINISHED',
  DESTROYED = 'DESTROYED',
}

export interface Card {
  cardId: string;
  type: CardType;
  color: CardColor;
  value: CardValue;
}

export interface PlayerHand {
  userId: string;
  cards: Card[];
}

export interface MatchState {
  matchId: string;
  roomId: string;
  players: string[];
  currentTurn: string;
  direction: GameDirection;
  currentColor: CardColor;
  currentValue: CardValue;
  drawPile: Card[];
  discardPile: Card[];
  hands: { [userId: string]: Card[] };
  status: MatchStatus;
  timerStarted: number;
  winner: string | null;
  totalTurns: number;

  /// Per-player counters, so statistics reflect what each player actually
  /// did rather than a match-wide total attributed to everyone.
  cardsPlayedBy?: Record<string, number>;
  cardsDrawnBy?: Record<string, number>;

  startedAt: number;
  unoCalledBy: string[];
  lastWildDrawFourBy?: string;
  lastWildDrawFourChallengeable?: boolean;

  /// Variants agreed in the lobby. Absent means the official game, which is
  /// what every match played before this existed was.
  houseRules?: HouseRules;

  /// Cards owed by the player to move next, built up by a stack of Draw Twos
  /// or Draw Fours. Zero when nothing is pending.
  pendingDraw?: number;

  /// Which card the pending stack is made of, so a Draw Two chain cannot be
  /// answered with a Draw Four.
  pendingDrawType?: CardValue.DRAW_TWO | CardValue.WILD_DRAW_FOUR;
}

export interface PlayCardInput {
  cardId: string;
  selectedColor?: CardColor;

  /// Target for the seven-zero swap. Only read when the seven-zero house
  /// rule is on and the card played is a 7.
  swapWith?: string;
}

export interface GameResult {
  matchId: string;
  winner: string;
  duration: number;
  totalTurns: number;
  players: GamePlayerResult[];
}

export interface GamePlayerResult {
  userId: string;
  finalPosition: number;
  cardsRemaining: number;
  ratingChange: number;
  xpEarned: number;
}