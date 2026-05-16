import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static String? _accessTokenCache;
  static String? _refreshTokenCache;

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

    final callbackUrl = ApiConstants.authCallbackUrl;
    if (callbackUrl.isNotEmpty) {
      body['email_redirect_to'] = callbackUrl;
    }

    final json = await ApiService.post(ApiConstants.registerEndpoint, body);
    final authResponse = AuthResponse.fromJson(json);

    // Only save tokens if email confirmation is not required
    if (!authResponse.emailConfirmationRequired) {
      await saveTokens(authResponse.accessToken, authResponse.refreshToken);
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
    await saveTokens(authResponse.accessToken, authResponse.refreshToken);
    return authResponse;
  }

  static Future<void> requestPasswordReset({required String email}) async {
    final body = <String, dynamic>{'email': email};
    final callbackUrl = ApiConstants.authCallbackUrl;
    if (callbackUrl.isNotEmpty) {
      body['redirect_to'] = callbackUrl;
    }

    await ApiService.post(ApiConstants.forgotPasswordEndpoint, body);
  }

  static Future<AuthResponse> exchangeCallback({
    required String tokenHash,
    required String callbackType,
  }) async {
    final json = await ApiService.post(
      '/api/v1/auth/exchange-callback',
      {
        'token_hash': tokenHash,
        'type': callbackType,
      },
    );

    final authResponse = AuthResponse.fromJson(json);
    await saveTokens(authResponse.accessToken, authResponse.refreshToken);
    return authResponse;
  }

  static Future<void> resetPassword({required String newPassword}) async {
    final body = <String, dynamic>{'password': newPassword};
    final refreshToken = await getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      body['refresh_token'] = refreshToken;
    }

    await ApiService.post(
      ApiConstants.resetPasswordEndpoint,
      body,
      requireAuth: true,
    );
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

  static Future<void> saveTokens(String access, String refresh) async {
    _accessTokenCache = access;
    _refreshTokenCache = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    if (_accessTokenCache != null) {
      return _accessTokenCache;
    }

    final prefs = await SharedPreferences.getInstance();
    _accessTokenCache = prefs.getString(_accessTokenKey);
    _refreshTokenCache ??= prefs.getString(_refreshTokenKey);
    return _accessTokenCache;
  }

  static Future<String?> getRefreshToken() async {
    if (_refreshTokenCache != null) {
      return _refreshTokenCache;
    }

    final prefs = await SharedPreferences.getInstance();
    _refreshTokenCache = prefs.getString(_refreshTokenKey);
    _accessTokenCache ??= prefs.getString(_accessTokenKey);
    return _refreshTokenCache;
  }

  static Future<void> clearTokens() async {
    _accessTokenCache = null;
    _refreshTokenCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
