export enum CurrencyType {
  COINS = 'COINS',
  GEMS = 'GEMS',
  EVENT_TOKENS = 'EVENT_TOKENS',
}

export enum CosmeticType {
  AVATAR = 'AVATAR',
  CARD_BACK = 'CARD_BACK',
  CARD_THEME = 'CARD_THEME',
  CARD_ANIMATION = 'CARD_ANIMATION',
  TABLE_THEME = 'TABLE_THEME',
  PROFILE_BANNER = 'PROFILE_BANNER',
  BADGE = 'BADGE',
  TITLE = 'TITLE',
  EMOTE = 'EMOTE',
  VOICE_PACK = 'VOICE_PACK',
}

export enum ItemRarity {
  COMMON = 'COMMON',
  RARE = 'RARE',
  EPIC = 'EPIC',
  LEGENDARY = 'LEGENDARY',
  MYTHIC = 'MYTHIC',
}

export interface StoreItem {
  itemId: string;
  name: string;
  description: string;
  type: CosmeticType;
  rarity: ItemRarity;
  price: number;
  currency: CurrencyType;
  imageUrl: string | null;
  isAvailable: boolean;
}

export interface PurchaseInput {
  itemId: string;
  cosmeticType: CosmeticType;
  currency: CurrencyType;
  price: number;
}

export interface EquipInput {
  cosmeticId: string;
  cosmeticType: CosmeticType;
}

export interface RewardInput {
  userId: string;
  coins?: number;
  gems?: number;
  xp?: number;
  cosmeticId?: string;
  cosmeticType?: CosmeticType;
  reason: string;
}