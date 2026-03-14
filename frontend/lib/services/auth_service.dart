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
      'has_diabetes': false,
      'has_hypertension': false,
      'has_heart_disease': false,
      'daily_calorie_goal': 2000.0,
    };

    final json = await ApiService.post(ApiConstants.registerEndpoint, body);
    final authResponse = AuthResponse.fromJson(json);
    await _saveTokens(authResponse.accessToken, authResponse.refreshToken);
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
}
