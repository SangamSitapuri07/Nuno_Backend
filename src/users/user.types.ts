export interface UpdateProfileInput {
  username?: string;
  avatarUrl?: string;
}

export interface UpdateSettingsInput {
  language?: string;
  musicVolume?: number;
  soundVolume?: number;
  voiceVolume?: number;
  pushToTalk?: boolean;
  notifications?: boolean;
  darkMode?: boolean;
}

export interface PlayerProfile {
  id: string;
  username: string;
  email: string;
  avatarUrl: string | null;
  level: number;
  xp: number;
  coins: number;
  rankPoints: number;
  accountStatus: string;
  createdAt: Date;
  lastLogin: Date | null;
  statistics: PlayerStats | null;
  leaderboard: PlayerRank | null;
}

export interface PlayerStats {
  gamesPlayed: number;
  gamesWon: number;
  gamesLost: number;
  winRate: number;
  longestWinStreak: number;
  currentWinStreak: number;
  cardsPlayed: number;
  cardsDrawn: number;
  totalPlayTime: bigint;
}

export interface PlayerRank {
  rating: number;
  tier: string;
  division: string;
  season: number;
}