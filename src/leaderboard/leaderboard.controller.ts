import { Request, Response } from 'express';
import leaderboardService from './leaderboard.service';
import { sendSuccess } from '../utils/response';
import asyncHandler from '../utils/asyncHandler';

export class LeaderboardController {

  // ─────────────────────────────────────────
  // GET GLOBAL LEADERBOARD
  // ─────────────────────────────────────────

  getGlobal = asyncHandler(async (req: Request, res: Response) => {
    const leaderboard = await leaderboardService.getGlobalLeaderboard();
    sendSuccess(res, leaderboard);
  });

  // ─────────────────────────────────────────
  // GET FRIENDS LEADERBOARD
  // ─────────────────────────────────────────

  getFriends = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const leaderboard = await leaderboardService.getFriendsLeaderboard(userId);
    sendSuccess(res, leaderboard);
  });

  // ─────────────────────────────────────────
  // GET PLAYER RANK
  // ─────────────────────────────────────────

  getPlayerRank = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const rank = await leaderboardService.getPlayerRank(userId);
    sendSuccess(res, rank);
  });

  // ─────────────────────────────────────────
  // GET MATCH HISTORY
  // ─────────────────────────────────────────

  getMatchHistory = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const history = await leaderboardService.getMatchHistory(userId);
    sendSuccess(res, history);
  });
}

export default new LeaderboardController();