import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/leaderboard_repository.dart';
import '../data/repositories/social_repository.dart';
import '../data/repositories/store_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/socket_service.dart';
import '../services/voice_service.dart';
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

/// WebRTC voice chat, driven by the socket's signalling relay.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService(ref.watch(socketServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Ties the REST session to the socket session.
///
/// The two halves need each other — a refreshed token has to reach the
/// socket, and a handshake the server rejects has to trigger a refresh — but
/// wiring that inside either provider would make them mutually dependent and
/// Riverpod cannot infer a type through a cycle. Keeping the callbacks here
/// leaves both providers standalone.
final sessionLinkProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  final socket = ref.watch(socketServiceProvider);

  // A renewed access token is useless to a socket still presenting the copy
  // it captured when it connected.
  api.onTokenRefreshed = socket.reauthenticate;

  // Conversely, a rejected handshake means the stored token has aged out;
  // renewing it re-runs the handshake through the callback above.
  socket.onAuthRejected = () async {
    await api.refreshSession();
  };
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
