import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/social_models.dart';
import '../models/user_models.dart';

/// /api/v1/leaderboard/*
class LeaderboardRepository {
  final ApiClient _api;

  LeaderboardRepository(this._api);

  Future<List<LeaderboardEntry>> getGlobal() async {
    final data = J.list(await _api.get('/leaderboard/global'));
    return data.map((e) => LeaderboardEntry.fromJson(J.map(e))).toList();
  }

  Future<List<LeaderboardEntry>> getFriends() async {
    final data = J.list(await _api.get('/leaderboard/friends'));
    return data.map((e) => LeaderboardEntry.fromJson(J.map(e))).toList();
  }

  /// Returns null when the player has no leaderboard row yet.
  Future<PlayerRank?> getMyRank() async {
    final data = await _api.get('/leaderboard/rank');
    if (data == null) return null;
    return PlayerRank.fromJson(J.map(data));
  }

  Future<List<MatchHistoryEntry>> getMatchHistory() async {
    final data = J.list(await _api.get('/leaderboard/history'));
    return data.map((e) => MatchHistoryEntry.fromJson(J.map(e))).toList();
  }
}
