import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account_sync.dart';
import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/social_models.dart';
import '../../data/models/user_models.dart';
import '../../services/socket_events.dart';
import '../auth/auth_controller.dart';

/// GET /api/v1/friends — refreshed live by `friend.statusUpdated`.
final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, List<Friend>>(FriendsNotifier.new);

class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    // Live presence updates from the socket.
    final socket = ref.watch(socketServiceProvider);
    final sub = socket.on(SocketEvents.friendStatusUpdated).listen((payload) {
      final userId = payload['userId']?.toString();
      final status = payload['status']?.toString();
      if (userId == null || status == null) return;
      _applyStatus(userId, status);
    });
    ref.onDispose(sub.cancel);

    // Presence broadcasts sent while we were disconnected are lost, so pull
    // the authoritative list again on every (re)authentication.
    final authSub = socket.onAuthenticated.listen((_) => refresh());
    ref.onDispose(authSub.cancel);

    // Friend requests can also arrive while offline.
    final reqSub = socket
        .on(SocketEvents.friendRequestAccepted)
        .listen((_) => refresh());
    ref.onDispose(reqSub.cancel);

    return ref.read(socialRepositoryProvider).getFriends();
  }

  void _applyStatus(String userId, String status) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final f in current)
        if (f.userId == userId)
          f.copyWith(status: PlayerOnlineStatusX.parse(status))
        else
          f,
    ]);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(socialRepositoryProvider).getFriends(),
    );
  }

  Future<void> remove(String friendId) async {
    await ref.read(socialRepositoryProvider).removeFriend(friendId);
    await refresh();
  }
}

/// Whether the home friends panel is showing.
///
/// Held outside the widget so toggling it does not rebuild the whole home
/// screen, and so the choice survives switching tabs and coming back.
final friendsPanelVisibleProvider = StateProvider<bool>((ref) => true);

/// GET /api/v1/messages/unread — unread DM totals keyed by friend id.
///
/// Refreshed whenever a message arrives, so the badge on the friends list
/// tracks reality without polling.
final unreadCountsProvider =
    AsyncNotifierProvider<UnreadCountsNotifier, Map<String, int>>(
        UnreadCountsNotifier.new);

class UnreadCountsNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final socket = ref.watch(socketServiceProvider);
    final sub = socket.on(SocketEvents.dmReceived).listen((_) => refresh());
    ref.onDispose(sub.cancel);

    return ref.read(socialRepositoryProvider).getUnreadCounts();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(socialRepositoryProvider).getUnreadCounts(),
    );
  }
}

/// GET /api/v1/friends/requests
final friendRequestsProvider =
    AsyncNotifierProvider<FriendRequestsNotifier, List<FriendRequest>>(
        FriendRequestsNotifier.new);

class FriendRequestsNotifier extends AsyncNotifier<List<FriendRequest>> {
  @override
  Future<List<FriendRequest>> build() async {
    final socket = ref.watch(socketServiceProvider);
    final sub =
        socket.on(SocketEvents.friendRequestReceived).listen((_) => refresh());
    ref.onDispose(sub.cancel);

    return ref.read(socialRepositoryProvider).getRequests();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(socialRepositoryProvider).getRequests(),
    );
  }

  Future<void> accept(String requestId) async {
    await ref.read(socialRepositoryProvider).acceptRequest(requestId);
    await refresh();
    await ref.read(friendsProvider.notifier).refresh();
  }

  Future<void> reject(String requestId) async {
    await ref.read(socialRepositoryProvider).rejectRequest(requestId);
    await refresh();
  }
}

/// GET /api/v1/notifications
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() =>
      ref.read(socialRepositoryProvider).getNotifications();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(socialRepositoryProvider).getNotifications(),
    );
  }

  Future<void> markAllRead() async {
    await ref.read(socialRepositoryProvider).markNotificationsRead();
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final n in current)
        AppNotification(
          id: n.id,
          title: n.title,
          message: n.message,
          read: true,
          createdAt: n.createdAt,
        ),
    ]);
  }
}

/// Count of unread notifications + pending friend requests.
final unreadBadgeProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ?? const <AppNotification>[];
  final requests = ref.watch(friendRequestsProvider).valueOrNull ??
      const <FriendRequest>[];
  return notifications.where((n) => !n.read).length + requests.length;
});

/// Online friends, sorted for the home carousel.
final onlineFriendsProvider = Provider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider).valueOrNull ?? const <Friend>[];
  final online = friends.where((f) => f.status.isOnline).toList()
    ..sort((a, b) => a.status.index.compareTo(b.status.index));
  return online;
});

/// GET /api/v1/statistics
final statisticsProvider = syncedWithAccount(FutureProvider<PlayerStats>(
    (ref) => ref.watch(userRepositoryProvider).getStatistics()));

/// GET /api/v1/history
final matchHistoryProvider =
    syncedWithAccount(FutureProvider<List<MatchHistoryEntry>>(
        (ref) => ref.watch(userRepositoryProvider).getMatchHistory()));

/// GET /api/v1/leaderboard/rank
final myRankProvider = syncedWithAccount(FutureProvider<PlayerRank?>(
    (ref) => ref.watch(leaderboardRepositoryProvider).getMyRank()));

/// Keeps the socket connected for as long as the user is authenticated.
///
/// This watches auth state rather than being read once, so signing in, a
/// token refresh, or a dropped connection all result in a reconnect.
final socketBootstrapProvider = Provider<void>((ref) {
  final isLoggedIn = ref.watch(authControllerProvider).isLoggedIn;
  final socket = ref.watch(socketServiceProvider);

  // Must be resolved before the socket connects, otherwise a token refreshed
  // mid-session never reaches the handshake.
  ref.watch(sessionLinkProvider);

  if (isLoggedIn) {
    socket.connect();
  } else {
    socket.disconnect();
  }
});
