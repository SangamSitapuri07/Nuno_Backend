import '../../core/network/api_client.dart';
import '../models/json.dart';
import '../models/user_models.dart';

/// /api/v1/profile, /settings, /statistics, /history
class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  Future<PlayerProfile> getProfile() async =>
      PlayerProfile.fromJson(J.map(await _api.get('/profile')));

  Future<void> updateProfile({String? username, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (body.isEmpty) return;
    await _api.put('/profile', body: body);
  }

  Future<PlayerSettings> getSettings() async =>
      PlayerSettings.fromJson(J.map(await _api.get('/settings')));

  Future<PlayerSettings> updateSettings(Map<String, dynamic> patch) async =>
      PlayerSettings.fromJson(J.map(await _api.put('/settings', body: patch)));

  Future<PlayerStats> getStatistics() async =>
      PlayerStats.fromJson(J.map(await _api.get('/statistics')));

  Future<List<MatchHistoryEntry>> getMatchHistory() async {
    final data = J.list(await _api.get('/history'));
    return data.map((e) => MatchHistoryEntry.fromJson(J.map(e))).toList();
  }
}
