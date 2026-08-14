import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/social_models.dart';
import '../models/user_models.dart';

/// /api/v1/friends, /players/search, /notifications, /reports, /block
class SocialRepository {
  final ApiClient _api;

  SocialRepository(this._api);

  // ── Friends ─────────────────────────────────────────────────

  Future<List<Friend>> getFriends() async {
    final data = J.list(await _api.get('/friends'));
    return data.map((e) => Friend.fromJson(J.map(e))).toList();
  }

  Future<List<FriendRequest>> getRequests() async {
    final data = J.list(await _api.get('/friends/requests'));
    return data.map((e) => FriendRequest.fromJson(J.map(e))).toList();
  }

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
