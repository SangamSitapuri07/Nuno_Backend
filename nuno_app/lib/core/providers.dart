import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/leaderboard_repository.dart';
import '../data/repositories/social_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/socket_service.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

/// Secure token store.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// REST client. On unrecoverable auth failure it clears the session, which the
/// router observes to bounce the user back to login.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: storage,
    onSessionExpired: () async {
      await storage.clear();
      ref.read(sessionExpiredProvider.notifier).state++;
    },
    onTokenRefreshed: () async {
      // Re-run the handshake with the fresh token. The socket captured the
      // old one when it connected, so it would otherwise keep failing auth
      // and silently queue every gameplay emit behind it.
      await ref.read(socketServiceProvider).reauthenticate();
    },
  );
});

/// Bumped whenever the session dies underneath us.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// Long-lived Socket.IO connection.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref.watch(tokenStorageProvider));

  // A rejected handshake means the stored access token has aged out. Driving
  // a REST call through the client triggers its refresh interceptor, which
  // then calls back into reauthenticate(). Read lazily: apiClientProvider
  // depends on this provider, so resolving it eagerly here would cycle.
  service.onAuthRejected = () async {
    try {
      await ref.read(apiClientProvider).get('/profile');
    } catch (_) {
      // Refresh failed; onSessionExpired has already routed to login.
    }
  };

  ref.onDispose(service.dispose);
  return service;
});

// ── Repositories ──────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(apiClientProvider)));

final socialRepositoryProvider = Provider<SocialRepository>(
    (ref) => SocialRepository(ref.watch(apiClientProvider)));

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
    (ref) => LeaderboardRepository(ref.watch(apiClientProvider)));

final storeRepositoryProvider =
    Provider<StoreRepository>((ref) => StoreRepository(ref.watch(apiClientProvider)));
