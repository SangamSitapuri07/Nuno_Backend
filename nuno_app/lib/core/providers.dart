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
  );
});

/// Bumped whenever the session dies underneath us.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// Long-lived Socket.IO connection.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref.watch(tokenStorageProvider));
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
