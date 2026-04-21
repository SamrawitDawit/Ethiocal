import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF8BC34A);
  static const Color background = Color(0xFFF6FAF2);
  static const Color cardFill = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color inputFill = Color(0xFFF2F7EC);
  static const Color inputBorder = Color(0xFFD5E8C8);
  static const Color error = Color(0xFFD32F2F);
  static const Color blobGreen = Color(0xFFA8D5A2);
  static const Color blobYellow = Color(0xFFE8E0A8);
}

class ApiConstants {
  // Web uses localhost directly; Android emulator uses 10.0.2.2 alias.
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  // Auth endpoints
  static const String registerEndpoint = '/api/v1/auth/register';
  static const String loginEndpoint = '/api/v1/auth/login';

  // User endpoints
  static const String setupProfileEndpoint = '/api/v1/users/setup-profile';
  static const String meEndpoint = '/api/v1/users/me';
  static const String profileEndpoint = '/api/v1/users/';

  // Meal endpoints
  static const String mealsEndpoint = '/api/v1/meals';
  static const String mealFoodItemsEndpoint = '/api/v1/meal-food-items';

  // Food endpoints
  static const String foodEndpoint = '/api/v1/food';
  static const String ingredientsEndpoint = '/api/v1/food/ingredients';
  static const String foodRecognizeEndpoint = '/api/v1/food/recognize';

  //Health Condition Endpoints
  static const String healthEndpoint = '/api/v1/health/';
  static const String mealCheckEndpoint = '/api/v1/health/meal-check';

  static const String nutritionDisclaimer =
      'These are general dietary targets based on 2026 ADA/AHA/Ethiopian NCD guidelines to support clinical goals (HbA1c <7.0%, BP <130/80, LDL <100 mg/dL or lower). They are not medical advice. Always consult your doctor.';

  // Notification endpoints
  static const String notificationsEndpoint = '/api/v1/notifications';

  // Leaderboard endpoint
  static const String leaderboardEndpoint = '/api/v1/leaderboard';
}

class RouteNames {
  static const String landing = '/';
  static const String signUp = '/sign-up';
  static const String login = '/login';
  static const String home = '/home';
  static const String mainNavigation = '/main';
  static const String mealEntry = '/meal-entry';
  static const String profileSetup = '/profile-setup';
  static const String profileSetupStep1 = '/profile-setup/step1';
  static const String profileSetupStep2 = '/profile-setup/step2';
  static const String profileSetupStep2_2 = '/profile-setup/step2-2';
  static const String profileSetupStep3 = '/profile-setup/step3';
  static const String foodRecognition = '/food-recognition';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String stats = '/stats';
  static const String leaderboard = '/leaderboard';
  static const String notificationSettings = '/notification-settings';
  static const String languageSettings = '/language-settings';
  static const String educationList = '/education';
  static const String educationDetail = '/education/detail';
}
