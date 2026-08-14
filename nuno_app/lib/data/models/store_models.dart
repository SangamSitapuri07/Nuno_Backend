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

  const OwnedCosmetic({
    required this.id,
    required this.cosmeticId,
    required this.cosmeticType,
    this.unlockedAt,
  });

  factory OwnedCosmetic.fromJson(Map<String, dynamic> json) => OwnedCosmetic(
        id: J.str(json['id']),
        cosmeticId: J.str(json['cosmeticId']),
        cosmeticType: CosmeticTypeX.parse(J.strOrNull(json['cosmeticType'])),
        unlockedAt: J.date(json['unlockedAt']),
      );

  @override
  List<Object?> get props => [id, cosmeticId];
}

/// GET /api/v1/inventory
class Inventory extends Equatable {
  final int coins;
  final List<OwnedCosmetic> cosmetics;

  const Inventory({this.coins = 0, this.cosmetics = const []});

  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
        coins: J.int_(J.map(json['currencies'])['coins']),
        cosmetics: J
            .list(json['cosmetics'])
            .map((e) => OwnedCosmetic.fromJson(J.map(e)))
            .toList(),
      );

  Set<String> get ownedIds => cosmetics.map((c) => c.cosmeticId).toSet();

  bool owns(String itemId) => ownedIds.contains(itemId);

  @override
  List<Object?> get props => [coins, cosmetics];
}
