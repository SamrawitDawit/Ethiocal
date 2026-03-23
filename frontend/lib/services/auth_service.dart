import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'full_name': fullName,
    };

    final json = await ApiService.post(ApiConstants.registerEndpoint, body);
    final authResponse = AuthResponse.fromJson(json);

    // Only save tokens if email confirmation is not required
    if (!authResponse.emailConfirmationRequired) {
      await _saveTokens(authResponse.accessToken, authResponse.refreshToken);
    }

    return authResponse;
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
    };

    final json = await ApiService.post(ApiConstants.loginEndpoint, body);
    final authResponse = AuthResponse.fromJson(json);
    await _saveTokens(authResponse.accessToken, authResponse.refreshToken);
    return authResponse;
  }

  static Future<User> setupProfile({
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    double dailyCalorieGoal = 2000.0,
    List<String> healthConditionIds = const [],
  }) async {
    final body = {
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'daily_calorie_goal': dailyCalorieGoal,
      'health_condition_ids': healthConditionIds,
    };

    final json = await ApiService.post(
      ApiConstants.setupProfileEndpoint,
      body,
      requireAuth: true,
    );
    return User.fromJson(json);
  }

  static Future<List<HealthCondition>> getHealthConditions() async {
    final json = await ApiService.getList(
      '${ApiConstants.meEndpoint.replaceAll('/me', '')}/health-conditions',
      requireAuth: true,
    );
    return json
        .map((e) => HealthCondition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
