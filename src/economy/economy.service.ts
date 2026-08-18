import prisma from '../config/database';
import logger from '../utils/logger';
import {
  PurchaseInput,
  RewardInput,
  EquipInput,
  CosmeticType,
  CurrencyType,
} from './economy.types';

export class EconomyService {

  // ─────────────────────────────────────────
  // GET INVENTORY
  // ─────────────────────────────────────────

  /// Items every player owns without buying them.
  ///
  /// These are granted as real rows rather than being special-cased in the
  /// client. The store used to show EQUIP on a default the player had no
  /// PlayerCosmetic row for, and equipping it failed with NOT_OWNED.
  private static readonly DEFAULT_ITEMS: Array<{
    itemId: string;
    type: CosmeticType;
  }> = [
    { itemId: 'card_back_classic', type: CosmeticType.CARD_BACK },
    { itemId: 'table_galaxy', type: CosmeticType.TABLE_THEME },
    { itemId: 'frame_bronze', type: CosmeticType.PROFILE_BANNER },
    { itemId: 'emote_laugh', type: CosmeticType.EMOTE },
    { itemId: 'title_rookie', type: CosmeticType.TITLE },
  ];

  /// Backfills the free items for a player who does not have them yet.
  ///
  /// Done on read so existing accounts pick them up too, not just ones
  /// created after this shipped. createMany with skipDuplicates leans on the
  /// (playerId, cosmeticId) unique index, so concurrent calls are safe.
  private async grantDefaults(userId: string): Promise<void> {
    await prisma.playerCosmetic.createMany({
      data: EconomyService.DEFAULT_ITEMS.map((d) => ({
        playerId: userId,
        cosmeticType: d.type as any,
        cosmeticId: d.itemId,
        // Equipped only if nothing of that type is set yet; resolved below.
        isEquipped: false,
      })),
      skipDuplicates: true,
    });

    // Make sure each type has exactly one equipped item. A player who has
    // never equipped anything would otherwise render nothing at all.
    const rows = await prisma.playerCosmetic.findMany({
      where: { playerId: userId },
    });

    const typesWithEquip = new Set(
      rows.filter((r: any) => r.isEquipped).map((r: any) => r.cosmeticType)
    );

    for (const d of EconomyService.DEFAULT_ITEMS) {
      if (typesWithEquip.has(d.type)) continue;
      const row = rows.find((r: any) => r.cosmeticId === d.itemId);
      if (!row) continue;
      await prisma.playerCosmetic.update({
        where: { id: row.id },
        data: { isEquipped: true },
      });
      typesWithEquip.add(d.type);
    }
  }

  async getInventory(userId: string) {
    await this.grantDefaults(userId);

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

    // A map of type -> equipped itemId, so the client does not have to scan
    // the whole list to answer "what am I using right now".
    const equipped: Record<string, string> = {};
    for (const c of cosmetics) {
      if (c.isEquipped) equipped[c.cosmeticType] = c.cosmeticId;
    }

    return {
      currencies: {
        coins: user?.coins || 0,
      },
      cosmetics,
      equipped,
    };
  }

  // ─────────────────────────────────────────
  // EQUIP COSMETIC
  // ─────────────────────────────────────────

  /// Makes an owned cosmetic the active one for its type.
  ///
  /// Buying something previously had no visible effect anywhere: ownership
  /// was recorded and nothing ever read it back. Exactly one item per type
  /// may be equipped, so this clears the others in the same transaction to
  /// avoid a window where a player has two card backs or none.
  async equipCosmetic(userId: string, input: EquipInput): Promise<void> {
    const owned = await prisma.playerCosmetic.findFirst({
      where: { playerId: userId, cosmeticId: input.cosmeticId },
    });

    if (!owned) {
      throw { code: 'NOT_OWNED', message: 'You do not own that item.', status: 403 };
    }

    await prisma.$transaction([
      prisma.playerCosmetic.updateMany({
        where: {
          playerId: userId,
          cosmeticType: owned.cosmeticType,
          isEquipped: true,
        },
        data: { isEquipped: false },
      }),
      prisma.playerCosmetic.update({
        where: { id: owned.id },
        data: { isEquipped: true },
      }),
    ]);

    logger.info('Cosmetic equipped', {
      userId,
      cosmeticId: input.cosmeticId,
      cosmeticType: owned.cosmeticType,
    });
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

    // Grant the item and put it straight into use. Buying something and then
    // having to find a separate equip control is a pointless second step,
    // and players reasonably expect what they just bought to be applied.
    await prisma.$transaction([
      prisma.playerCosmetic.updateMany({
        where: {
          playerId: userId,
          cosmeticType: input.cosmeticType as any,
          isEquipped: true,
        },
        data: { isEquipped: false },
      }),
      prisma.playerCosmetic.create({
        data: {
          playerId: userId,
          cosmeticType: input.cosmeticType as any,
          cosmeticId: input.itemId,
          isEquipped: true,
        },
      }),
    ]);

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
    // Deliberately small.
    //
    // The catalogue used to advertise around eighty items, but only a
    // handful had artwork and nothing bought could actually be equipped, so
    // most of it was decoration. Every entry below has real art in the app
    // and a real effect once equipped. Anything priced in gems was also
    // removed: the User model only has `coins`, so those were unbuyable.
    return [
      // ═══ CARD BACKS - the design shown on face-down cards ═══
      { itemId: 'card_back_classic', name: 'Classic Back', description: 'The original Nuno back', type: 'CARD_BACK', rarity: 'COMMON', price: 0, currency: 'COINS', imageUrl: null, isAvailable: true, isDefault: true },
      { itemId: 'card_back_neon', name: 'Neon City', description: 'Cyberpunk glow', type: 'CARD_BACK', rarity: 'RARE', price: 600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_gold', name: 'Gold Leaf', description: 'Gilded finish', type: 'CARD_BACK', rarity: 'EPIC', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_fire', name: 'Fire Storm', description: 'Blazing ember burst', type: 'CARD_BACK', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_ocean', name: 'Ocean Wave', description: 'Deep sea crest', type: 'CARD_BACK', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_forest', name: 'Wildgrove', description: 'Leaf and vine', type: 'CARD_BACK', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_royal', name: 'Royal Filigree', description: 'Gold on deep purple', type: 'CARD_BACK', rarity: 'EPIC', price: 1800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_frost', name: 'Frostbite', description: 'Crystalline shards', type: 'CARD_BACK', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_sunset', name: 'Sundown', description: 'Art-deco sunburst', type: 'CARD_BACK', rarity: 'EPIC', price: 1600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_circuit', name: 'Mainframe', description: 'Live circuitry', type: 'CARD_BACK', rarity: 'EPIC', price: 1900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'card_back_diamond', name: 'Diamond Elite', description: 'Ultra rare finish', type: 'CARD_BACK', rarity: 'LEGENDARY', price: 4000, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ TABLE THEMES - the background behind the table ═══
      { itemId: 'table_galaxy', name: 'Galaxy Table', description: 'Deep space vortex', type: 'TABLE_THEME', rarity: 'COMMON', price: 0, currency: 'COINS', imageUrl: null, isAvailable: true, isDefault: true },
      { itemId: 'table_midnight', name: 'Midnight Table', description: 'Calm violet felt', type: 'TABLE_THEME', rarity: 'RARE', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_emerald', name: 'Emerald Table', description: 'Classic green felt', type: 'TABLE_THEME', rarity: 'RARE', price: 800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_aurora', name: 'Aurora Table', description: 'Shifting aurora light', type: 'TABLE_THEME', rarity: 'EPIC', price: 1800, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_royal', name: 'Royal Table', description: 'Purple velvet and gold', type: 'TABLE_THEME', rarity: 'EPIC', price: 2000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'table_lava', name: 'Molten Table', description: 'Cracked volcanic rock', type: 'TABLE_THEME', rarity: 'LEGENDARY', price: 3200, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ AVATAR FRAMES - the ring around your avatar ═══
      { itemId: 'frame_bronze', name: 'Bronze Frame', description: 'Where everyone starts', type: 'PROFILE_BANNER', rarity: 'COMMON', price: 0, currency: 'COINS', imageUrl: null, isAvailable: true, isDefault: true },
      { itemId: 'frame_silver', name: 'Silver Frame', description: 'Polished silver ring', type: 'PROFILE_BANNER', rarity: 'RARE', price: 500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_gold', name: 'Gold Frame', description: 'For the consistent winner', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_emerald', name: 'Wildgrove Frame', description: 'Bronze wrapped in leaves', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_epic', name: 'Epic Frame', description: 'Radiant arcane ring', type: 'PROFILE_BANNER', rarity: 'LEGENDARY', price: 3000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_frost', name: 'Frostbite Frame', description: 'Carved from ice', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_circuit', name: 'Mainframe Frame', description: 'Live circuit traces', type: 'PROFILE_BANNER', rarity: 'EPIC', price: 1500, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'frame_inferno', name: 'Inferno Frame', description: 'Forged in embers', type: 'PROFILE_BANNER', rarity: 'LEGENDARY', price: 3400, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ AVATARS - your portrait ═══
      //
      // The default is the generated initials tile, so it has no art entry
      // and cannot be bought or unequipped.
      { itemId: 'avatar_warrior', name: 'Warrior', description: 'Steel and nerve', type: 'AVATAR', rarity: 'RARE', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_rogue', name: 'Rogue', description: 'Plays close to the chest', type: 'AVATAR', rarity: 'RARE', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_wizard', name: 'Wizard', description: 'Reads the table', type: 'AVATAR', rarity: 'EPIC', price: 2000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_ninja', name: 'Ninja', description: 'Never sees it coming', type: 'AVATAR', rarity: 'RARE', price: 900, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_pirate', name: 'Captain', description: 'Takes what is dealt', type: 'AVATAR', rarity: 'EPIC', price: 2000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_robot', name: 'Unit-7', description: 'Calculates every draw', type: 'AVATAR', rarity: 'EPIC', price: 2200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_alien', name: 'Visitor', description: 'Not from this table', type: 'AVATAR', rarity: 'LEGENDARY', price: 3600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_detective', name: 'Detective', description: 'Reads every tell', type: 'AVATAR', rarity: 'RARE', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_jester', name: 'Jester', description: 'Plays for the laugh', type: 'AVATAR', rarity: 'RARE', price: 1000, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_astronaut', name: 'Astronaut', description: 'Cool under pressure', type: 'AVATAR', rarity: 'EPIC', price: 2400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_vampire', name: 'Count', description: 'Waits for the right card', type: 'AVATAR', rarity: 'LEGENDARY', price: 3400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'avatar_queen', name: 'Queen', description: 'Rules every round', type: 'AVATAR', rarity: 'LEGENDARY', price: 3800, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ TITLES - shown under your name ═══
      //
      // Text rather than art, so these need no asset and cannot end up
      // looking like a placeholder.
      { itemId: 'title_rookie', name: 'Rookie', description: 'Everyone starts here', type: 'TITLE', rarity: 'COMMON', price: 0, currency: 'COINS', imageUrl: null, isAvailable: true, isDefault: true },
      { itemId: 'title_sharp', name: 'Sharp Shuffler', description: 'Quick with a deck', type: 'TITLE', rarity: 'COMMON', price: 200, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_champion', name: 'Champion', description: 'Proven winner', type: 'TITLE', rarity: 'RARE', price: 600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_untouchable', name: 'Untouchable', description: 'Never seen losing', type: 'TITLE', rarity: 'EPIC', price: 1400, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'title_legend', name: 'Legend', description: 'Spoken of in whispers', type: 'TITLE', rarity: 'LEGENDARY', price: 3500, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ BADGES - a medal beside your name ═══
      { itemId: 'badge_star', name: 'Star Badge', description: 'A bright start', type: 'BADGE', rarity: 'COMMON', price: 250, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_cards', name: 'Card Badge', description: 'For the regulars', type: 'BADGE', rarity: 'COMMON', price: 250, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_flame', name: 'Flame Badge', description: 'On a hot streak', type: 'BADGE', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_bolt', name: 'Bolt Badge', description: 'Lightning fast', type: 'BADGE', rarity: 'RARE', price: 700, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_first', name: 'First Place', description: 'Top of the table', type: 'BADGE', rarity: 'EPIC', price: 1600, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'badge_crown', name: 'Crown Badge', description: 'Rules the room', type: 'BADGE', rarity: 'LEGENDARY', price: 3200, currency: 'COINS', imageUrl: null, isAvailable: true },

      // ═══ EMOTES - sent from the table ═══
      { itemId: 'emote_laugh', name: 'Laugh', description: 'Ha ha!', type: 'EMOTE', rarity: 'COMMON', price: 0, currency: 'COINS', imageUrl: null, isAvailable: true, isDefault: true },
      { itemId: 'emote_cool', name: 'Cool', description: 'Too easy', type: 'EMOTE', rarity: 'COMMON', price: 150, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_clap', name: 'Clap', description: 'Well played', type: 'EMOTE', rarity: 'COMMON', price: 150, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_shock', name: 'Shocked', description: 'You did not', type: 'EMOTE', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_cry', name: 'Cry', description: 'Not again', type: 'EMOTE', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
      { itemId: 'emote_angry', name: 'Angry', description: 'Grrr!', type: 'EMOTE', rarity: 'RARE', price: 300, currency: 'COINS', imageUrl: null, isAvailable: true },
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