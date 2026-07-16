import { Request, Response } from 'express';
import friendsService from './friends.service';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';

export class FriendsController {

  // ─────────────────────────────────────────
  // GET FRIENDS
  // ─────────────────────────────────────────

  getFriends = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const friends = await friendsService.getFriends(userId);
    sendSuccess(res, friends);
  });

  // ─────────────────────────────────────────
  // SEND FRIEND REQUEST
  // ─────────────────────────────────────────

  sendRequest = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const { playerId } = req.body;

    if (!playerId) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Player ID is required.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    await friendsService.sendFriendRequest(userId, playerId);
    sendSuccess(res, { message: 'Friend request sent.' }, HTTP_STATUS.CREATED);
  });

  // ─────────────────────────────────────────
  // ACCEPT REQUEST
  // ─────────────────────────────────────────

  acceptRequest = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const { requestId } = req.body;

    if (!requestId) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Request ID is required.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    await friendsService.acceptFriendRequest(userId, requestId);
    sendSuccess(res, { message: 'Friend request accepted.' });
  });

  // ─────────────────────────────────────────
  // REJECT REQUEST
  // ─────────────────────────────────────────

  rejectRequest = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const { requestId } = req.body;

    if (!requestId) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Request ID is required.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    await friendsService.rejectFriendRequest(userId, requestId);
    sendSuccess(res, { message: 'Friend request rejected.' });
  });

  // ─────────────────────────────────────────
  // REMOVE FRIEND
  // ─────────────────────────────────────────

 removeFriend = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const friendId = req.params.friendId as string;

    await friendsService.removeFriend(userId, friendId);
    sendSuccess(res, { message: 'Friend removed.' });
  });

  // ─────────────────────────────────────────
  // GET REQUESTS
  // ─────────────────────────────────────────

  getRequests = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const requests = await friendsService.getFriendRequests(userId);
    sendSuccess(res, requests);
  });

  // ─────────────────────────────────────────
  // SEARCH PLAYERS
  // ─────────────────────────────────────────

  searchPlayers = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const query = req.query.query as string;

    if (!query || query.length < 2) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Search query must be at least 2 characters.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    const players = await friendsService.searchPlayers(query, userId);
    sendSuccess(res, players);
  });

  // ─────────────────────────────────────────
  // GET NOTIFICATIONS
  // ─────────────────────────────────────────

  getNotifications = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const notifications = await friendsService.getNotifications(userId);
    sendSuccess(res, notifications);
  });

  // ─────────────────────────────────────────
  // MARK NOTIFICATIONS READ
  // ─────────────────────────────────────────

  markNotificationsRead = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    await friendsService.markNotificationsRead(userId);
    sendSuccess(res, { message: 'Notifications marked as read.' });
  });
}

export default new FriendsController();