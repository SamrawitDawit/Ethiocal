import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders(
      {bool requireAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await AuthService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API POST: $url');

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('HTTP request failed: $e');
      rethrow;
    }

    debugPrint('API response ${response.statusCode}: ${response.body}');

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }

    final errorMessage = decoded is Map && decoded.containsKey('detail')
        ? decoded['detail']
        : 'Something went wrong. Please try again.';
    throw ApiException(errorMessage, response.statusCode);
  }

  static Future<List<dynamic>> get(
    String endpoint, {
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API GET: $url');

    final http.Response response;
    try {
      response = await http.get(
        url,
        headers: headers,
      );
    } catch (e) {
      debugPrint('HTTP request failed: $e');
      rethrow;
    }

    debugPrint('API response ${response.statusCode}: ${response.body}');

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as List<dynamic>;
    }

    final errorMessage = decoded is Map && decoded.containsKey('detail')
        ? decoded['detail']
        : 'Something went wrong. Please try again.';
    throw ApiException(errorMessage, response.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
