export enum RankTier {
  BRONZE = 'BRONZE',
  SILVER = 'SILVER',
  GOLD = 'GOLD',
  PLATINUM = 'PLATINUM',
  DIAMOND = 'DIAMOND',
  MASTER = 'MASTER',
  GRANDMASTER = 'GRANDMASTER',
}

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string;
  avatarUrl: string | null;
  rating: number;
  tier: string;
  division: string;
  wins: number;
}

export interface XPReward {
  baseXP: number;
  victoryBonus: number;
  totalXP: number;
}

export interface RatingChange {
  oldRating: number;
  newRating: number;
  change: number;
  newTier: string;
  newDivision: string;
}

export const TIER_THRESHOLDS: { [key: string]: number } = {
  BRONZE: 0,
  SILVER: 500,
  GOLD: 1000,
  PLATINUM: 1500,
  DIAMOND: 2000,
  MASTER: 2500,
  GRANDMASTER: 3000,
};

export const XP_REWARDS = {
  MATCH_COMPLETED: 50,
  VICTORY_BONUS: 75,
  MVP_BONUS: 25,
  DAILY_MISSION: 100,
  WEEKLY_MISSION: 300,
};

export const LEVEL_THRESHOLDS = [
  0, 100, 250, 450, 700, 1000, 1350, 1750,
  2200, 2700, 3250, 3850, 4500, 5200, 5950,
  6750, 7600, 8500, 9450, 10450,
];