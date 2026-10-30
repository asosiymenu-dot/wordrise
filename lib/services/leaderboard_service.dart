import '../models/api_models.dart';
import 'api_service.dart';

class LeaderboardService {
  LeaderboardService(this._api);

  final ApiService _api;

  Future<List<LeaderboardUserModel>> global() =>
      _load('/leaderboard/global.php');

  Future<List<LeaderboardUserModel>> daily() => _load('/leaderboard/daily.php');

  Future<List<LeaderboardUserModel>> weekly() =>
      _load('/leaderboard/weekly.php');

  Future<List<LeaderboardUserModel>> friends({String scope = 'global'}) =>
      _load('/leaderboard/friends.php', query: {'scope': scope});

  Future<List<LeaderboardUserModel>> _load(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _api.get(path, query: query);
    return (data['leaderboard'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardUserModel.fromJson)
        .toList();
  }
}
