import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/social_models.dart';
import '../models/user_models.dart';

/// /api/v1/friends, /players/search, /notifications, /reports, /block
class SocialRepository {
  final ApiClient _api;

  SocialRepository(this._api);

  // ── Direct messages ─────────────────────────────────────────

  /// The stored conversation with one friend, oldest first.
  ///
  /// Fetching this is also what marks it read server-side, so the unread
  /// badge clears exactly when the player opens the thread.
  Future<List<DirectMessage>> getConversation(String friendId) async {
    final data = J.list(await _api.get('/messages/$friendId'));
    return data.map((e) => DirectMessage.fromJson(J.map(e))).toList();
  }

  /// Unread totals keyed by friend id.
  Future<Map<String, int>> getUnreadCounts() async {
    final data = J.map(await _api.get('/messages/unread'));
    return data.map((k, v) => MapEntry(k, J.int_(v)));
  }

  /// Sends over REST. The socket is the usual path; this is the fallback so
  /// a message is not lost when the socket happens to be down.
  Future<DirectMessage> sendMessage(String friendId, String message) async {
    final data = J.map(await _api.post(
      '/messages',
      body: {'friendId': friendId, 'message': message},
    ));
    return DirectMessage.fromJson(data);
  }

  // ── Friends ─────────────────────────────────────────────────

  Future<List<Friend>> getFriends() async {
    final data = J.list(await _api.get('/friends'));
    return data.map((e) => Friend.fromJson(J.map(e))).toList();
  }

  Future<List<FriendRequest>> getRequests() async {
    final data = J.list(await _api.get('/friends/requests'));
    return data.map((e) => FriendRequest.fromJson(J.map(e))).toList();
  }

  /// Sends a request to whoever owns [uid].
  ///
  /// Resolved server-side, so the app never needs the target's internal id -
  /// which is the whole point of having a public number.
  Future<void> sendRequestByUid(String uid) =>
      _api.post('/friends/request/uid', body: {'uid': uid});

  Future<void> sendRequest(String playerId) =>
      _api.post('/friends/request', body: {'playerId': playerId});

  Future<void> acceptRequest(String requestId) =>
      _api.post('/friends/accept', body: {'requestId': requestId});

  Future<void> rejectRequest(String requestId) =>
      _api.post('/friends/reject', body: {'requestId': requestId});

  Future<void> removeFriend(String friendId) =>
      _api.delete('/friends/$friendId');

  /// Backend requires at least 2 characters.
  Future<List<PlayerSearchResult>> searchPlayers(String query) async {
    if (query.trim().length < 2) return const [];
    final data = J.list(
      await _api.get('/players/search', query: {'query': query.trim()}),
    );
    return data.map((e) => PlayerSearchResult.fromJson(J.map(e))).toList();
  }

  // ── Notifications ───────────────────────────────────────────

  Future<List<AppNotification>> getNotifications() async {
    final data = J.list(await _api.get('/notifications'));
    return data.map((e) => AppNotification.fromJson(J.map(e))).toList();
  }

  Future<void> markNotificationsRead() => _api.patch('/notifications/read');

  // ── Moderation ──────────────────────────────────────────────

  Future<void> reportPlayer({
    required String playerId,
    required String reason,
    String? matchId,
  }) =>
      _api.post('/reports', body: {
        'playerId': playerId,
        'reason': reason,
        if (matchId != null) 'matchId': matchId,
      });

  Future<void> blockPlayer(String playerId) =>
      _api.post('/block', body: {'playerId': playerId});

  Future<void> unblockPlayer(String playerId) => _api.delete('/block/$playerId');

  Future<List<String>> getBlockedPlayers() async {
    final data = J.list(await _api.get('/block'));
    return data
        .map((e) => e is Map ? J.str(e['id'] ?? e['playerId']) : e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
