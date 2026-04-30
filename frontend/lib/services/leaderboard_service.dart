import '../models/leaderboard_model.dart';
import '../services/api_service.dart';

class LeaderboardService {
  Future<LeaderboardResponse> getLeaderboard({
    int days = 30,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'days': days.toString(),
        'limit': limit.toString(),
      };
      
      final json = await ApiService.get(
        '/api/v1/leaderboard',
        requireAuth: true,
        queryParams: queryParams,
      );
      
      return LeaderboardResponse.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error fetching leaderboard: $e');
    }
  }
}
