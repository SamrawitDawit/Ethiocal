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
  // Web uses localhost directly; mobile/desktop can override with --dart-define=API_HOST.
  // Example for physical phone on same Wi-Fi: --dart-define=API_HOST=192.168.1.42
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.0.2.2',
  );

  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://$_apiHost:8000';
  static const String registerEndpoint = '/api/v1/auth/register';
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String foodRecognizeEndpoint = '/api/v1/food/recognize';
}

class RouteNames {
  static const String landing = '/';
  static const String signUp = '/sign-up';
  static const String login = '/login';
  static const String foodRecognition = '/food-recognition';
}
