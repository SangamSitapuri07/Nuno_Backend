import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/store_models.dart';
import '../auth/auth_controller.dart';

/// The inventory, refreshed after every purchase or equip.
///
/// Keyed on the signed-in user: without that, signing out and back in as
/// somebody else would leave the previous player's cosmetics on the table.
final inventoryProvider = FutureProvider<Inventory>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(storeRepositoryProvider).getInventory();
});

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

  /// Ring drawn around the player's avatar, or null when the player has not
  /// equipped one - callers then fall back to the level-derived frame.
  final String? avatarFrame;

  /// Emote KEYS the player may send, matching Emotes.glyphs - so 'laugh',
  /// not the store's 'emote_laugh'. The defaults are always available.
  final Set<String> emotes;

  /// Medal shown beside the player's name, or null when none is equipped.
  final String? badge;

  /// Title shown under the player's name, or null when none is equipped.
  final String? title;

  const EquippedCosmetics({
    required this.cardBack,
    required this.tableTheme,
    required this.avatarFrame,
    required this.emotes,
    this.badge,
    this.title,
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
      // Store ids are prefixed ('emote_laugh'); the sheet and the socket
      // both speak the bare key ('laugh').
      emotes: {
        ..._freeEmotes,
        for (final id in owned)
          if (id.startsWith('emote_')) id.substring('emote_'.length),
      },
      badge: Art.badge(inventory?.equippedFor(CosmeticType.badge) ?? ''),
      title: _titleText(inventory?.equippedFor(CosmeticType.title)),
    );
  }

  /// Granted to everyone, matching the isDefault entries in the catalogue.
  static const _freeEmotes = {'laugh'};

  /// Titles are words rather than pictures, so they map to display text.
  static String? _titleText(String? itemId) => switch (itemId) {
        'title_rookie' => 'Rookie',
        'title_sharp' => 'Sharp Shuffler',
        'title_champion' => 'Champion',
        'title_untouchable' => 'Untouchable',
        'title_legend' => 'Legend',
        _ => null,
      };

  static String _cardBackAsset(String? itemId) => switch (itemId) {
        'card_back_neon' => Art.skinNeon,
        'card_back_gold' => Art.skinGold,
        'card_back_diamond' => Art.skinDiamond,
        'card_back_fire' => Art.skinFire,
        'card_back_ocean' => Art.skinOcean,
        'card_back_classic' => Art.skinClassic,
        // The 3D render is the default back, and the one the table used
        // before any of this existed.
        _ => Art.cardBack3d,
      };

  static String _tableAsset(String? itemId) => switch (itemId) {
        'table_midnight' => Art.bgPanel,
        'table_aurora' => Art.bgStore,
        _ => Art.bgTable,
      };

  static String? _frameAsset(String? itemId) => switch (itemId) {
        'frame_bronze' => Art.frameBronze,
        'frame_silver' => Art.frameSilver,
        'frame_gold' => Art.frameGold,
        'frame_epic' => Art.frameEpic,
        // Nothing equipped: let the level decide, as it did before.
        _ => null,
      };
}
