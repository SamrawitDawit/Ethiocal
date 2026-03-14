import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiService {
  static final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    debugPrint('API POST: $url');

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: _defaultHeaders,
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
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
