import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One place that says "the signed-in account has changed on the server".
///
/// Coins, rating, tier and level are read by five different screens through
/// four different providers:
///
///   * the home header      -> the cached profile
///   * the store header     -> inventoryProvider
///   * the profile card     -> the cached profile
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
/// ## Why a counter, and not `ref.invalidate`
///
/// The first version of this held a list of providers and had the auth
/// controller invalidate them all. That deadlocks Riverpod with a circular
/// dependency, and it is worth spelling out why, because the shape is easy
/// to recreate:
///
///   * `inventoryProvider` reads `currentUserIdProvider`, which reads
///     `authControllerProvider` - so inventory DEPENDS ON auth.
///   * the auth controller then called `ref.invalidate(inventoryProvider)`,
///     which makes Riverpod record auth as DEPENDING ON inventory.
///
/// Both directions at once is a cycle, and Riverpod throws
/// "Instance of CircularDependencyError" the moment anything touches it -
/// which is every button in the app, because buying, claiming and finishing
/// a match all refresh the profile.
///
/// Depending on a counter inverts the arrows. Nothing account-scoped is
/// named here; each cache reads [accountRevisionProvider] itself, so every
/// edge points from the cache TO the counter and the graph stays acyclic.
/// Bumping it re-runs them all.
final accountRevisionProvider = StateProvider<int>((ref) => 0);

/// Marks the surrounding provider as account-scoped: it re-runs whenever
/// [AccountSync.refresh] is called.
///
/// Call this first inside the provider body:
///
/// ```dart
/// final inventoryProvider = FutureProvider<Inventory>((ref) {
///   watchAccount(ref);
///   return ref.watch(storeRepositoryProvider).getInventory();
/// });
/// ```
///
/// Deliberately a `watch` on a counter rather than a registration list. A
/// provider that forgets to call this simply keeps its old value, which is
/// visible in the UI; a provider that registers itself with a central
/// invalidator creates the cycle described above, which is not.
void watchAccount(Ref ref) {
  ref.watch(accountRevisionProvider);
}

abstract final class AccountSync {
  /// Re-reads every account-scoped cache from the server.
  ///
  /// Safe to call from a provider, a notifier or a widget: it only ever
  /// touches the counter, which depends on nothing.
  static void refresh(Ref ref) {
    ref.read(accountRevisionProvider.notifier).state++;
  }

  /// Same, from a widget.
  static void refreshFrom(WidgetRef ref) {
    ref.read(accountRevisionProvider.notifier).state++;
  }
}
