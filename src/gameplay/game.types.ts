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
  startedAt: number;
  unoCalledBy: string[];
  lastWildDrawFourBy?: string;
  lastWildDrawFourChallengeable?: boolean;
}

export interface PlayCardInput {
  cardId: string;
  selectedColor?: CardColor;
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