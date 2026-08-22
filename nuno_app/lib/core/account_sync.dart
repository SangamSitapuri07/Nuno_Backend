import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One place that says "the signed-in account has changed on the server".
///
/// Coins, rating, tier and level are read by five different screens through
/// four different providers:
///
///   * the home header      -> authControllerProvider.profile.coins
///   * the store header     -> inventoryProvider.coins
///   * the profile card     -> authControllerProvider.profile
///   * the rank header      -> myRankProvider
///   * the rank rows        -> global/friendsLeaderboardProvider
///
/// Every one of those is a separate cache with no expiry. `FutureProvider`
/// resolves once and holds the value for as long as something is listening,
/// and the tabs live in an `IndexedStack`, so all five stay mounted and
/// listening for the whole session. Whichever screen happened to load first
/// kept the balance from that moment, which is how the home header could say
/// 750 while the store said 540, and why the rank header disagreed with the
/// row for the same player.
///
/// Bumping this counter invalidates the lot together. Anything that changes
/// money or rating - a purchase, a daily claim, the end of a match - calls
/// [AccountSync.refresh] and every screen re-reads from the server.
final accountRevisionProvider = StateProvider<int>((ref) => 0);

/// Providers that must be re-fetched when the account changes.
///
/// Registered rather than imported so this file stays free of feature
/// imports and cannot create an import cycle: each feature adds its own
/// provider at declaration time.
final _dependents = <ProviderOrFamily>[];

/// Registers [provider] to be invalidated on the next [AccountSync.refresh].
///
/// Call once, at declaration. Returns [provider] so it can be used inline.
T syncedWithAccount<T extends ProviderOrFamily>(T provider) {
  if (!_dependents.contains(provider)) _dependents.add(provider);
  return provider;
}

abstract final class AccountSync {
  /// Invalidates every account-scoped cache.
  ///
  /// Callers do not await this: the providers refetch themselves and the
  /// widgets rebuild when they land.
  static void refresh(Ref ref) {
    for (final p in _dependents) {
      ref.invalidate(p);
    }
    ref.read(accountRevisionProvider.notifier).state++;
  }

  /// Same, from a widget.
  static void refreshFrom(WidgetRef ref) {
    for (final p in _dependents) {
      ref.invalidate(p);
    }
    ref.read(accountRevisionProvider.notifier).state++;
  }

  /// Visible for testing: how many providers are wired up.
  static int get registeredCount => _dependents.length;
}
