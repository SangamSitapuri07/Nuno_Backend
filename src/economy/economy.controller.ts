import { Request, Response } from 'express';
import economyService from './economy.service';
import { sendSuccess, sendError } from '../utils/response';
import { HTTP_STATUS, ERROR_CODES } from '../utils/constants';
import asyncHandler from '../utils/asyncHandler';
import { PurchaseInput } from './economy.types';

export class EconomyController {

  // ─────────────────────────────────────────
  // GET INVENTORY
  // ─────────────────────────────────────────

  getInventory = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const inventory = await economyService.getInventory(userId);
    sendSuccess(res, inventory);
  });

  // ─────────────────────────────────────────
  // GET STORE
  // ─────────────────────────────────────────

  getStore = asyncHandler(async (req: Request, res: Response) => {
    const items = await economyService.getStoreItems();
    sendSuccess(res, items);
  });

  // ─────────────────────────────────────────
  // PURCHASE ITEM
  // ─────────────────────────────────────────

  purchaseItem = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const input: PurchaseInput = req.body;

    if (!input?.itemId || !input?.cosmeticType || !input?.currency) {
      sendError(
        res,
        ERROR_CODES.VALIDATION_ERROR,
        'Invalid purchase request.',
        HTTP_STATUS.BAD_REQUEST
      );
      return;
    }

    await economyService.purchaseItem(userId, input);
    sendSuccess(res, { message: 'Item purchased successfully.' });
  });

  // ─────────────────────────────────────────
  // CLAIM DAILY REWARD
  // ─────────────────────────────────────────

  claimDailyReward = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    await economyService.claimDailyReward(userId);
    sendSuccess(res, { message: 'Daily reward claimed successfully.' });
  });

  // ─────────────────────────────────────────
  // GET BALANCE
  // ─────────────────────────────────────────

  getBalance = asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as any).user?.userId;
    const balance = await economyService.getCurrencyBalance(userId);
    sendSuccess(res, balance);
  });
}

export default new EconomyController();