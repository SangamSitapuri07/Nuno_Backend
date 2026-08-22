import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account_sync.dart';
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
  watchAccount(ref);
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
  final TableBackdrop tableTheme;

  /// Ring drawn around the player's avatar, or null when the player has not
  /// equipped one - callers then fall back to the level-derived frame.
  final String? avatarFrame;

  /// Emote KEYS the player may send, matching Emotes.glyphs - so 'laugh',
  /// not the store's 'emote_laugh'. The defaults are always available.
  final Set<String> emotes;

  /// Portrait asset, or null to keep the generated initials tile.
  final String? avatar;

  /// Medal shown beside the player's name, or null when none is equipped.
  final String? badge;

  /// Title shown under the player's name, or null when none is equipped.
  final String? title;

  const EquippedCosmetics({
    required this.cardBack,
    required this.tableTheme,
    required this.avatarFrame,
    required this.emotes,
    this.avatar,
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
      tableTheme: _tableBackdrop(
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
      avatar: Art.avatar(inventory?.equippedFor(CosmeticType.avatar) ?? ''),
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
        'card_back_royal' => Art.skinRoyal,
        'card_back_forest' => Art.skinForest,
        'card_back_circuit' => Art.skinCircuit,
        'card_back_frost' => Art.skinFrost,
        'card_back_sunset' => Art.skinSunset,
        'card_back_classic' => Art.skinClassic,
        // The 3D render is the default back, and the one the table used
        // before any of this existed.
        _ => Art.cardBack3d,
      };

  /// Backdrop for the game table.
  ///
  /// Three themes have a full-bleed photograph; the other two are painted
  /// gradients. Both are real backdrops - a gradient is not a placeholder -
  /// which lets the catalogue grow without waiting on more artwork.
  static TableBackdrop _tableBackdrop(String? itemId) => switch (itemId) {
        'table_midnight' => const TableBackdrop(asset: Art.bgPanel),
        'table_aurora' => const TableBackdrop(asset: Art.bgStore),
        'table_emerald' => const TableBackdrop(
            colors: [Color(0xFF0B3B2A), Color(0xFF05160F)],
          ),
        'table_lava' => const TableBackdrop(
            colors: [Color(0xFF5A1503), Color(0xFF17060B)],
          ),
        'table_royal' => const TableBackdrop(
            colors: [Color(0xFF3B1466), Color(0xFF120726)],
          ),
        _ => const TableBackdrop(asset: Art.bgTable),
      };

  static String? _frameAsset(String? itemId) => switch (itemId) {
        'frame_bronze' => Art.frameBronze,
        'frame_silver' => Art.frameSilver,
        'frame_gold' => Art.frameGold,
        'frame_epic' => Art.frameEpic,
        'frame_emerald' => Art.frameEmerald,
        'frame_inferno' => Art.frameInferno,
        'frame_frost' => Art.frameFrost,
        'frame_circuit' => Art.frameCircuit,
        // Nothing equipped: let the level decide, as it did before.
        _ => null,
      };
}


/// What to paint behind the game table: either a full-bleed image or a
/// two-stop radial gradient.
@immutable
class TableBackdrop {
  final String? asset;
  final List<Color>? colors;

  const TableBackdrop({this.asset, this.colors})
      : assert(asset != null || colors != null,
            'a backdrop needs either an asset or colours');
}

/// The one number every screen shows as "your coins".
///
/// The home header used to read `profile.coins` and the store header read
/// `inventory.coins`. Those are two independent caches with no expiry, so
/// whichever loaded first kept its value - which is how the home screen said
/// 750 while the store said 540 at the same moment.
///
/// Everything now reads this. The inventory is preferred because it is
/// refetched immediately after a purchase; the cached profile is the
/// fallback for screens opened before the store has ever loaded. Both are
/// invalidated together by AccountSync, so they cannot drift apart.
final coinBalanceProvider = Provider<int>((ref) {
  final inventory = ref.watch(inventoryProvider).valueOrNull;
  if (inventory != null) return inventory.coins;
  return ref.watch(currentProfileProvider)?.coins ?? 0;
});
