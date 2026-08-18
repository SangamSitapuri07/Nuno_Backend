import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/store_models.dart';

/// The inventory, refreshed after every purchase or equip.
final inventoryProvider = FutureProvider<Inventory>(
  (ref) => ref.watch(storeRepositoryProvider).getInventory(),
);

/// Which cosmetics are actually in use, resolved to concrete asset paths.
///
/// Buying an item used to change nothing anywhere in the game - ownership was
/// recorded and never read back. This is the single place that answers "what
/// should the table and cards look like for this player", so screens do not
/// each have to map item ids to assets.
final equippedCosmeticsProvider = Provider<EquippedCosmetics>((ref) {
  final inventory = ref.watch(inventoryProvider).valueOrNull;
  return EquippedCosmetics.from(inventory);
});

class EquippedCosmetics {
  /// Art for the back of a face-down card.
  final String cardBack;

  /// Background behind the game table.
  final String tableTheme;

  /// Ring drawn around the player's avatar.
  final String avatarFrame;

  /// Emote ids the player may send. The defaults are always available.
  final Set<String> emotes;

  const EquippedCosmetics({
    required this.cardBack,
    required this.tableTheme,
    required this.avatarFrame,
    required this.emotes,
  });

  /// Falls back to the free default for anything not owned or not equipped,
  /// so a player with an empty inventory still gets a complete table.
  factory EquippedCosmetics.from(Inventory? inventory) {
    final owned = inventory?.ownedIds ?? const <String>{};

    return EquippedCosmetics(
      cardBack: _cardBackAsset(
        inventory?.equippedFor(CosmeticType.cardBack),
      ),
      tableTheme: _tableAsset(
        inventory?.equippedFor(CosmeticType.tableTheme),
      ),
      avatarFrame: _frameAsset(
        inventory?.equippedFor(CosmeticType.profileBanner),
      ),
      // Emotes are additive rather than exclusive: owning one unlocks it.
      emotes: {
        ..._freeEmotes,
        ...owned.where((id) => id.startsWith('emote_')),
      },
    );
  }

  static const _freeEmotes = {'emote_laugh'};

  static String _cardBackAsset(String? itemId) => switch (itemId) {
        'card_back_neon' => Art.skinNeon,
        'card_back_gold' => Art.skinGold,
        'card_back_diamond' => Art.skinDiamond,
        'card_back_classic' => Art.skinClassic,
        // The 3D render is the default back, and the one the table used
        // before any of this existed.
        _ => Art.cardBack3d,
      };

  static String _tableAsset(String? itemId) => switch (itemId) {
        'table_panel' => Art.bgPanel,
        'table_store' => Art.bgStore,
        _ => Art.bgTable,
      };

  static String _frameAsset(String? itemId) => switch (itemId) {
        'frame_silver' => Art.frameSilver,
        'frame_gold' => Art.frameGold,
        'frame_epic' => Art.frameEpic,
        _ => Art.frameBronze,
      };
}
