import '../models/health_condition_model.dart';
import '../models/profile_model.dart';
import 'api_service.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getCurrentProfile() async {
    try {
      final response = await ApiService.get('/api/v1/users/me', requireAuth: true);
      return response;
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  static Future<Map<String, dynamic>> updateBasicProfile({
    String? fullName,
    String? languagePreference,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (languagePreference != null) body['language_preference'] = languagePreference;

      final response = await ApiService.patch('/api/v1/users/me', body, requireAuth: true);
      return response;
    } catch (e) {
      throw Exception('Failed to update basic profile: $e');
    }
  }

  static Future<Map<String, dynamic>> updateProfileData({
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    double? dailyCalorieGoal,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender;
      if (height != null) body['height'] = height;
      if (weight != null) body['weight'] = weight;
      if (activityLevel != null) body['activity_level'] = activityLevel;
      if (dailyCalorieGoal != null) body['daily_calorie_goal'] = dailyCalorieGoal;

      final response = await ApiService.patch('/api/v1/users/profile', body, requireAuth: true);
      return response;
    } catch (e) {
      throw Exception('Failed to update profile data: $e');
    }
  }

  static Future<List<HealthCondition>> getHealthConditions() async {
    try {
      final response = await ApiService.getList('/api/v1/users/health-conditions', requireAuth: true);
      return response.map((json) => HealthCondition.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load health conditions: $e');
    }
  }

  static Future<Map<String, dynamic>> createProfile({
    required Profile profile,
  }) async {
    try {
      final response = await ApiService.patch('/api/v1/user-profile/me', profile.toJson(), requireAuth: true);
      return response;
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  static Future<bool> hasProfile() async {
    try {
      // Try to get user profile - if it exists, user has completed setup
      final profile = await getCurrentProfile();
      return profile['age'] != null;
    } catch (e) {
      // If profile doesn't exist, API will return 404
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return false;
      }
      // For other errors, we don't know - assume no profile to be safe
      return false;
    }
  }
}
