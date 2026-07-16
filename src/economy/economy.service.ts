import prisma from '../config/database';
import logger from '../utils/logger';
import {
  PurchaseInput,
  RewardInput,
  CosmeticType,
  CurrencyType,
} from './economy.types';

export class EconomyService {

  // ─────────────────────────────────────────
  // GET INVENTORY
  // ─────────────────────────────────────────

  async getInventory(userId: string) {
    const cosmetics = await prisma.playerCosmetic.findMany({
      where: { playerId: userId },
      orderBy: { unlockedAt: 'desc' },
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        coins: true,
      },
    });

    return {
      currencies: {
        coins: user?.coins || 0,
      },
      cosmetics,
    };
  }

  // ─────────────────────────────────────────
  // PURCHASE ITEM
  // ─────────────────────────────────────────

  async purchaseItem(
    userId: string,
    input: PurchaseInput
  ): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { coins: true },
    });

    if (!user) {
      throw { code: 'USER_NOT_FOUND', message: 'User not found.', status: 404 };
    }

    // Check if already owned
    const existing = await prisma.playerCosmetic.findFirst({
      where: {
        playerId: userId,
        cosmeticId: input.itemId,
      },
    });

    if (existing) {
      throw { code: 'ALREADY_OWNED', message: 'Item already owned.', status: 409 };
    }

    // Validate currency
    if (input.currency === CurrencyType.COINS) {
      if (user.coins < input.price) {
        throw { code: 'INSUFFICIENT_FUNDS', message: 'Not enough coins.', status: 400 };
      }

      // Deduct coins
      await prisma.user.update({
        where: { id: userId },
        data: { coins: { decrement: input.price } },
      });
    }

    // Grant item
    await prisma.playerCosmetic.create({
      data: {
        playerId: userId,
        cosmeticType: input.cosmeticType as any,
        cosmeticId: input.itemId,
      },
    });

    logger.info('Item purchased', {
      userId,
      itemId: input.itemId,
      price: input.price,
      currency: input.currency,
    });
  }

  // ─────────────────────────────────────────
  // GRANT REWARD
  // ─────────────────────────────────────────

  async grantReward(input: RewardInput): Promise<void> {
    const updateData: any = {};

    if (input.coins) {
      updateData.coins = { increment: input.coins };
    }

    if (input.xp) {
      updateData.xp = { increment: input.xp };
    }

    if (Object.keys(updateData).length > 0) {
      await prisma.user.update({
        where: { id: input.userId },
        data: updateData,
      });
    }

    // Grant cosmetic if provided
    if (input.cosmeticId && input.cosmeticType) {
      const existing = await prisma.playerCosmetic.findFirst({
        where: {
          playerId: input.userId,
          cosmeticId: input.cosmeticId,
        },
      });

      if (!existing) {
        await prisma.playerCosmetic.create({
          data: {
            playerId: input.userId,
            cosmeticType: input.cosmeticType as any,
            cosmeticId: input.cosmeticId,
          },
        });
      }
    }

    // Create notification
    await prisma.notification.create({
      data: {
        playerId: input.userId,
        title: 'Reward Received',
        message: `You received a reward: ${input.reason}`,
      },
    });

    logger.info('Reward granted', {
      userId: input.userId,
      reason: input.reason,
      coins: input.coins,
      xp: input.xp,
    });
  }

  // ─────────────────────────────────────────
  // GET DAILY REWARD
  // ─────────────────────────────────────────

  async claimDailyReward(userId: string): Promise<void> {
    const lastClaimKey = `daily:${userId}`;
    const lastClaim = await import('../config/redis').then(
      (m) => m.default.get(lastClaimKey)
    );

    if (lastClaim) {
      throw {
        code: 'ALREADY_CLAIMED',
        message: 'Daily reward already claimed.',
        status: 400,
      };
    }

    // Grant daily reward
    await this.grantReward({
      userId,
      coins: 100,
      xp: 50,
      reason: 'Daily Login Reward',
    });

    // Set 24 hour expiry
    const redis = await import('../config/redis').then((m) => m.default);
    await redis.set(lastClaimKey, '1', { EX: 86400 });

    logger.info('Daily reward claimed', { userId });
  }

  // ─────────────────────────────────────────
  // GET STORE ITEMS
  // ─────────────────────────────────────────

  async getStoreItems() {
    return [
      // ═══ FEATURED ═══
      { itemId: 'bundle_starter', name: 'Starter Bundle', description: 'Avatar + Card Back + 500 coins', type: 'AVATAR', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true, originalPrice: 800, discountPercent: 37 },
      { itemId: 'bundle_premium', name: 'Premium Bundle', description: 'Everything you need', type: 'AVATAR', rarity: 'LEGENDARY', price: 3000, currency: 'COINS', imageUrl: null, isAvailable: true, originalPrice: 5000, discountPercent: 40, isLimited: true },

      // ═══ CARD PACKS ═══
      { itemId: 'pack_classic', name: 'Classic Pack', description: '5 random cards', type: 'CARD_BACK', rarity: 'COMMON', price: 200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'pack_neon', name: 'Neon Pack', description: '5 rare cards', type: 'CARD_BACK', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'pack_gold', name: 'Gold Pack', description: '5 epic cards', type: 'CARD_BACK', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'pack_diamond', name: 'Diamond Pack', description: '5 legendary cards', type: 'CARD_BACK', rarity: 'LEGENDARY', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ CARD BACKS ═══
      { itemId: 'back_classic', name: 'Classic Back', description: 'Traditional design', type: 'CARD_BACK', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'back_galaxy', name: 'Galaxy Back', description: 'Cosmic space theme', type: 'CARD_BACK', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'back_fire', name: 'Fire Storm', description: 'Blazing fire design', type: 'CARD_BACK', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'back_ocean', name: 'Ocean Wave', description: 'Deep sea design', type: 'CARD_BACK', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'back_neon', name: 'Neon City', description: 'Cyberpunk aesthetic', type: 'CARD_BACK', rarity: 'LEGENDARY', price: 2500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'back_diamond', name: 'Diamond Elite', description: 'Ultra rare finish', type: 'CARD_BACK', rarity: 'MYTHIC', price: 5000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ CARD THEMES ═══
      { itemId: 'theme_classic', name: 'Classic Theme', description: 'Original card design', type: 'CARD_THEME', rarity: 'COMMON', price: 150, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'theme_dark', name: 'Dark Theme', description: 'Sleek dark cards', type: 'CARD_THEME', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'theme_holographic', name: 'Holographic', description: 'Shimmering cards', type: 'CARD_THEME', rarity: 'LEGENDARY', price: 3000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'theme_rainbow', name: 'Rainbow', description: 'Colorful gradient', type: 'CARD_THEME', rarity: 'EPIC', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ TABLE THEMES ═══
      { itemId: 'table_classic', name: 'Classic Table', description: 'Green felt table', type: 'TABLE_THEME', rarity: 'COMMON', price: 200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_space', name: 'Space Table', description: 'Galaxy background', type: 'TABLE_THEME', rarity: 'RARE', price: 600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_neon', name: 'Neon Table', description: 'Glowing neon', type: 'TABLE_THEME', rarity: 'EPIC', price: 1200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_royal', name: 'Royal Table', description: 'Gold and velvet', type: 'TABLE_THEME', rarity: 'LEGENDARY', price: 2500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ AVATARS ═══
      { itemId: 'avatar_default', name: 'Default Avatar', description: 'Classic look', type: 'AVATAR', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_warrior', name: 'Warrior', description: 'Battle-tested', type: 'AVATAR', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_wizard', name: 'Wizard', description: 'Mystical powers', type: 'AVATAR', rarity: 'EPIC', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_dragon', name: 'Dragon Lord', description: 'Fire breather', type: 'AVATAR', rarity: 'LEGENDARY', price: 2000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_god', name: 'Cosmic God', description: 'Divine being', type: 'AVATAR', rarity: 'MYTHIC', price: 5000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ EMOTES ═══
      { itemId: 'emote_laugh', name: 'Laugh', description: 'Ha ha!', type: 'EMOTE', rarity: 'COMMON', price: 50, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_angry', name: 'Angry', description: 'Grrr!', type: 'EMOTE', rarity: 'COMMON', price: 50, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_cool', name: 'Cool', description: 'Too cool', type: 'EMOTE', rarity: 'RARE', price: 200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_dab', name: 'Dab', description: 'Show off', type: 'EMOTE', rarity: 'EPIC', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_crown', name: 'King Wave', description: 'Royal greeting', type: 'EMOTE', rarity: 'LEGENDARY', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ TITLES ═══
      { itemId: 'title_rookie', name: 'Rookie', description: 'Just starting', type: 'TITLE', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_champion', name: 'Champion', description: 'Proven winner', type: 'TITLE', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_legend', name: 'Legend', description: 'Legendary status', type: 'TITLE', rarity: 'EPIC', price: 1200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_god', name: 'The God', description: 'Ultimate title', type: 'TITLE', rarity: 'MYTHIC', price: 5000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ BADGES ═══
      { itemId: 'badge_bronze', name: 'Bronze Badge', description: 'Bronze tier', type: 'BADGE', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_silver', name: 'Silver Badge', description: 'Silver tier', type: 'BADGE', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_gold', name: 'Gold Badge', description: 'Gold tier', type: 'BADGE', rarity: 'EPIC', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_diamond', name: 'Diamond Badge', description: 'Diamond tier', type: 'BADGE', rarity: 'LEGENDARY', price: 2500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ PROFILE BANNERS ═══
      { itemId: 'banner_fire', name: 'Fire Banner', description: 'Flaming background', type: 'PROFILE_BANNER', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'banner_ice', name: 'Ice Banner', description: 'Frozen aesthetic', type: 'PROFILE_BANNER', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'banner_space', name: 'Space Banner', description: 'Cosmic wallpaper', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ VOICE PACKS ═══
      { itemId: 'voice_hero', name: 'Hero Voice', description: 'Heroic lines', type: 'VOICE_PACK', rarity: 'EPIC', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'voice_villain', name: 'Villain Voice', description: 'Evil lines', type: 'VOICE_PACK', rarity: 'EPIC', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ COIN PACKS ═══
      { itemId: 'coins_500', name: '500 Coins', description: 'Small coin pack', type: 'BADGE', rarity: 'COMMON', price: 50, currency: 'GEMS', imageUrl: null, isAvailable: true },
      { itemId: 'coins_2000', name: '2000 Coins', description: 'Medium coin pack', type: 'BADGE', rarity: 'RARE', price: 150, currency: 'GEMS', imageUrl: null, isAvailable: true },
      { itemId: 'coins_5000', name: '5000 Coins', description: 'Large coin pack', type: 'BADGE', rarity: 'EPIC', price: 350, currency: 'GEMS', imageUrl: null, isAvailable: true },
    
      // AVATARS
      { itemId: 'avatar_nova_001', name: 'Nova Avatar', description: 'Classic Nova player', type: 'AVATAR', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_warrior', name: 'Warrior Avatar', description: 'Battle-tested warrior', type: 'AVATAR', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_wizard', name: 'Wizard Avatar', description: 'Mystical spell caster', type: 'AVATAR', rarity: 'EPIC', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_dragon', name: 'Dragon Lord', description: 'Legendary dragon rider', type: 'AVATAR', rarity: 'LEGENDARY', price: 2000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_god', name: 'God Avatar', description: 'Divine cosmic being', type: 'AVATAR', rarity: 'MYTHIC', price: 5000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // CARD BACKS
      { itemId: 'card_back_classic', name: 'Classic Back', description: 'Traditional design', type: 'CARD_BACK', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_galaxy', name: 'Galaxy Back', description: 'Cosmic space theme', type: 'CARD_BACK', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_fire', name: 'Fire Storm', description: 'Blazing fire pattern', type: 'CARD_BACK', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_ocean', name: 'Ocean Wave', description: 'Deep sea design', type: 'CARD_BACK', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_neon', name: 'Neon City', description: 'Cyberpunk aesthetic', type: 'CARD_BACK', rarity: 'LEGENDARY', price: 2500, currency: 'COINS', imageUrl: null, isAvailable: true, originalPrice: 3000, discountPercent: 20 },
      { itemId: 'card_back_diamond', name: 'Diamond Elite', description: 'Ultra rare diamond finish', type: 'CARD_BACK', rarity: 'MYTHIC', price: 8000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // CARD THEMES
      { itemId: 'theme_classic', name: 'Classic Theme', description: 'Original card design', type: 'CARD_THEME', rarity: 'COMMON', price: 150, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'theme_dark', name: 'Dark Theme', description: 'Sleek dark cards', type: 'CARD_THEME', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'theme_holographic', name: 'Holographic', description: 'Shimmering effect', type: 'CARD_THEME', rarity: 'LEGENDARY', price: 3000, currency: 'COINS', imageUrl: null, isAvailable: true, isLimited: true },

      // EMOTES
      { itemId: 'emote_laugh', name: 'Laugh', description: 'Ha ha ha!', type: 'EMOTE', rarity: 'COMMON', price: 50, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_angry', name: 'Angry', description: 'Grrr!', type: 'EMOTE', rarity: 'COMMON', price: 50, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_cool', name: 'Cool', description: 'Too cool for school', type: 'EMOTE', rarity: 'RARE', price: 200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_dab', name: 'Dab', description: 'Show off your dab', type: 'EMOTE', rarity: 'EPIC', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_crown', name: 'King Wave', description: 'Royal greeting', type: 'EMOTE', rarity: 'LEGENDARY', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // TITLES
      { itemId: 'title_champion', name: 'Champion', description: 'Show your victories', type: 'TITLE', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_legend', name: 'Legend', description: 'Legendary status', type: 'TITLE', rarity: 'EPIC', price: 1200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_god', name: 'The God', description: 'Ultimate title', type: 'TITLE', rarity: 'MYTHIC', price: 5000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // BADGES
      { itemId: 'badge_bronze', name: 'Bronze Badge', description: 'Bronze tier achievement', type: 'BADGE', rarity: 'COMMON', price: 100, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_silver', name: 'Silver Badge', description: 'Silver tier achievement', type: 'BADGE', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_gold', name: 'Gold Badge', description: 'Gold tier achievement', type: 'BADGE', rarity: 'EPIC', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_diamond', name: 'Diamond Badge', description: 'Diamond tier', type: 'BADGE', rarity: 'LEGENDARY', price: 2500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // PROFILE BANNERS
      { itemId: 'banner_fire', name: 'Fire Banner', description: 'Flaming background', type: 'PROFILE_BANNER', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'banner_ice', name: 'Ice Banner', description: 'Frozen aesthetic', type: 'PROFILE_BANNER', rarity: 'RARE', price: 400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'banner_space', name: 'Space Banner', description: 'Cosmic wallpaper', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // VOICE PACKS
      { itemId: 'voice_pack_hero', name: 'Hero Voice', description: 'Heroic voice lines', type: 'VOICE_PACK', rarity: 'EPIC', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'voice_pack_villain', name: 'Villain Voice', description: 'Evil voice lines', type: 'VOICE_PACK', rarity: 'EPIC', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },

      // BUNDLES (LIMITED)
      { itemId: 'bundle_starter', name: 'Starter Bundle', description: 'Avatar + Card Back + 100 coins', type: 'AVATAR', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true, originalPrice: 800, discountPercent: 37 },
      { itemId: 'bundle_premium', name: 'Premium Bundle', description: 'Everything you need', type: 'AVATAR', rarity: 'LEGENDARY', price: 3000, currency: 'COINS', imageUrl: null, isAvailable: true, originalPrice: 5000, discountPercent: 40, isLimited: true },
    ];
  }

  // ─────────────────────────────────────────
  // ADD COINS
  // ─────────────────────────────────────────

  async addCoins(userId: string, amount: number): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: { coins: { increment: amount } },
    });

    logger.info('Coins added', { userId, amount });
  }

  // ─────────────────────────────────────────
  // GET CURRENCY BALANCE
  // ─────────────────────────────────────────

  async getCurrencyBalance(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { coins: true },
    });

    return {
      coins: user?.coins || 0,
    };
  }
}

export default new EconomyService();