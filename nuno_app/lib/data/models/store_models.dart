import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json.dart';

/// GET /api/v1/store  (src/economy/economy.service.ts → getStoreItems)
class StoreItem extends Equatable {
  final String itemId;
  final String name;
  final String description;
  final CosmeticType type;
  final ItemRarity rarity;
  final int price;
  final CurrencyType currency;
  final String? imageUrl;
  final bool isAvailable;
  final int? originalPrice;
  final int? discountPercent;
  final bool isLimited;

  /// Granted to every player, so it is owned without being bought.
  final bool isDefault;

  const StoreItem({
    required this.itemId,
    required this.name,
    this.description = '',
    this.type = CosmeticType.avatar,
    this.rarity = ItemRarity.common,
    this.price = 0,
    this.currency = CurrencyType.coins,
    this.imageUrl,
    this.isAvailable = true,
    this.originalPrice,
    this.discountPercent,
    this.isLimited = false,
    this.isDefault = false,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) => StoreItem(
        itemId: J.str(json['itemId']),
        name: J.str(json['name']),
        description: J.str(json['description']),
        type: CosmeticTypeX.parse(J.strOrNull(json['type'])),
        rarity: ItemRarityX.parse(J.strOrNull(json['rarity'])),
        price: J.int_(json['price']),
        currency: CurrencyTypeX.parse(J.strOrNull(json['currency'])),
        imageUrl: J.strOrNull(json['imageUrl']),
        isAvailable: J.bool_(json['isAvailable'], true),
        originalPrice:
            json['originalPrice'] == null ? null : J.int_(json['originalPrice']),
        discountPercent: json['discountPercent'] == null
            ? null
            : J.int_(json['discountPercent']),
        isLimited: J.bool_(json['isLimited']),
        isDefault: J.bool_(json['isDefault']),
      );

  /// Body for POST /api/v1/store/purchase
  Map<String, dynamic> toPurchasePayload() => {
        'itemId': itemId,
        'cosmeticType': type.wire,
        'currency': currency.wire,
        'price': price,
      };

  bool get isDiscounted =>
      (discountPercent ?? 0) > 0 && (originalPrice ?? 0) > price;

  @override
  List<Object?> get props => [itemId, price, isAvailable];
}

/// Entry of `cosmetics` from GET /api/v1/inventory (Prisma PlayerCosmetic)
class OwnedCosmetic extends Equatable {
  final String id;
  final String cosmeticId;
  final CosmeticType cosmeticType;
  final DateTime? unlockedAt;
  final bool isEquipped;

  const OwnedCosmetic({
    required this.id,
    required this.cosmeticId,
    required this.cosmeticType,
    this.unlockedAt,
    this.isEquipped = false,
  });

  factory OwnedCosmetic.fromJson(Map<String, dynamic> json) => OwnedCosmetic(
        id: J.str(json['id']),
        cosmeticId: J.str(json['cosmeticId']),
        cosmeticType: CosmeticTypeX.parse(J.strOrNull(json['cosmeticType'])),
        unlockedAt: J.date(json['unlockedAt']),
        isEquipped: J.bool_(json['isEquipped']),
      );

  @override
  List<Object?> get props => [id, cosmeticId, isEquipped];
}

/// GET /api/v1/inventory
class Inventory extends Equatable {
  final int coins;
  final List<OwnedCosmetic> cosmetics;

  /// cosmetic type wire name -> the itemId currently in use for it.
  final Map<String, String> equipped;

  const Inventory({
    this.coins = 0,
    this.cosmetics = const [],
    this.equipped = const {},
  });

  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
        coins: J.int_(J.map(json['currencies'])['coins']),
        cosmetics: J
            .list(json['cosmetics'])
            .map((e) => OwnedCosmetic.fromJson(J.map(e)))
            .toList(),
        equipped: J.map(json['equipped']).map(
              (k, v) => MapEntry(k, v.toString()),
            ),
      );

  Set<String> get ownedIds => cosmetics.map((c) => c.cosmeticId).toSet();

  bool owns(String itemId) => ownedIds.contains(itemId);

  /// The item in use for [type], or null when the player has equipped none.
  String? equippedFor(CosmeticType type) => equipped[type.wire];

  bool isEquipped(String itemId) => equipped.containsValue(itemId);

  @override
  List<Object?> get props => [coins, cosmetics, equipped];
}

/// GET / POST /api/v1/rewards/daily
///
/// The seven-day track and which day is next both come from the server. The
/// app used to hard-code the reward table and a fixed "current day" of 2, so
/// the track it drew had no relationship to what the account had claimed.
class DailyReward extends Equatable {
  final int day;
  final int coins;
  final int xp;

  const DailyReward({required this.day, this.coins = 0, this.xp = 0});

  factory DailyReward.fromJson(Map<String, dynamic> json) => DailyReward(
        day: J.int_(json['day']),
        coins: J.int_(json['coins']),
        xp: J.int_(json['xp']),
      );

  @override
  List<Object?> get props => [day, coins, xp];
}

class DailyStatus extends Equatable {
  /// 1-7. The day that is claimable now, or the one just claimed today.
  final int currentDay;

  /// Consecutive days claimed, 0 once the streak has lapsed.
  final int streak;

  final bool claimedToday;
  final bool canClaim;
  final List<DailyReward> rewards;

  const DailyStatus({
    this.currentDay = 1,
    this.streak = 0,
    this.claimedToday = false,
    this.canClaim = true,
    this.rewards = const [],
  });

  factory DailyStatus.fromJson(Map<String, dynamic> json) => DailyStatus(
        currentDay: J.int_(json['currentDay'], 1).clamp(1, 7),
        streak: J.int_(json['streak']),
        claimedToday: J.bool_(json['claimedToday']),
        canClaim: J.bool_(json['canClaim'], true),
        rewards: J
            .list(json['rewards'])
            .map((e) => DailyReward.fromJson(J.map(e)))
            .toList(),
      );

  @override
  List<Object?> get props => [currentDay, streak, claimedToday, canClaim, rewards];
}
