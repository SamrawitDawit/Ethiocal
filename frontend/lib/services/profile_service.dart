import '../models/health_condition_model.dart';
import '../models/profile_model.dart';
import 'api_service.dart';

class ProfileService {
  static Future<List<HealthCondition>> getHealthConditions() async {
    try {
      final response = await ApiService.get('/api/v1/health/', requireAuth: true);
      return response.map((json) => HealthCondition.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load health conditions: $e');
    }
  }

  static Future<Map<String, dynamic>> createProfile({
    required Profile profile,
  }) async {
    try {
      final response = await ApiService.post('/api/v1/profile/', profile.toJson(), requireAuth: true);
      return response;
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  static Future<bool> hasProfile() async {
    try {
      // Try to get user profile - if it exists, user has completed setup
      await ApiService.get('/api/v1/profile/me', requireAuth: true);
      return true;
    } catch (e) {
      // If profile doesn't exist, API will return 404
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return false;
      }
      throw Exception('Failed to check profile status: $e');
    }
  }
}
