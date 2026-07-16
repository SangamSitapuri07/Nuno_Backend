import leaderboardService from '../../leaderboard/leaderboard.service';
import { RankTier } from '../../leaderboard/leaderboard.types';

describe('LeaderboardService', () => {

  describe('getLevelFromXP', () => {
    it('should return level 1 for 0 XP', () => {
      const level = leaderboardService.getLevelFromXP(0);
      expect(level).toBe(1);
    });

    it('should return level 2 for 100 XP', () => {
      const level = leaderboardService.getLevelFromXP(100);
      expect(level).toBe(2);
    });

    it('should return level 3 for 250 XP', () => {
      const level = leaderboardService.getLevelFromXP(250);
      expect(level).toBe(3);
    });
  });

  describe('getTierFromRating', () => {
    it('should return BRONZE for rating 0', () => {
      const { tier } = leaderboardService.getTierFromRating(0);
      expect(tier).toBe(RankTier.BRONZE);
    });

    it('should return SILVER for rating 500', () => {
      const { tier } = leaderboardService.getTierFromRating(500);
      expect(tier).toBe(RankTier.SILVER);
    });

    it('should return GOLD for rating 1000', () => {
      const { tier } = leaderboardService.getTierFromRating(1000);
      expect(tier).toBe(RankTier.GOLD);
    });

    it('should return PLATINUM for rating 1500', () => {
      const { tier } = leaderboardService.getTierFromRating(1500);
      expect(tier).toBe(RankTier.PLATINUM);
    });

    it('should return DIAMOND for rating 2000', () => {
      const { tier } = leaderboardService.getTierFromRating(2000);
      expect(tier).toBe(RankTier.DIAMOND);
    });
  });

  describe('calculateXP', () => {
    it('should return base XP for loss', () => {
      const xp = leaderboardService.calculateXP(false);
      expect(xp).toBe(50);
    });

    it('should return base XP plus victory bonus for win', () => {
      const xp = leaderboardService.calculateXP(true);
      expect(xp).toBe(125);
    });

    it('should return XP with MVP bonus', () => {
      const xp = leaderboardService.calculateXP(true, true);
      expect(xp).toBe(150);
    });
  });
});