import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/app_constants.dart';
import 'auth_service.dart';

class ApiService {
  static Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, String>> _getHeaders(
      {bool requireAuth = false}) async {
    final headers = Map<String, String>.from(_defaultHeaders);

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

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requireAuth = false,
    Map<String, String>? queryParams,
  }) async {
    var url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParams != null) {
      url = url.replace(queryParameters: queryParams);
    }
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API GET: $url');

    final http.Response response;
    try {
      response = await http.get(url, headers: headers);
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

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API PATCH: $url');

    final http.Response response;
    try {
      response = await http.patch(
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

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API PUT: $url');

    final http.Response response;
    try {
      response = await http.put(
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

  static Future<List<dynamic>> getList(
    String endpoint, {
    bool requireAuth = false,
    Map<String, String>? queryParams,
  }) async {
    var url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParams != null) {
      url = url.replace(queryParameters: queryParams);
    }
    final headers = await _getHeaders(requireAuth: requireAuth);
    debugPrint('API GET List: $url');

    final http.Response response;
    try {
      response = await http.get(url, headers: headers);
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

  /// Upload a file using multipart form data
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    List<int> fileBytes,
    String filename, {
    String fieldName = 'image',
    String? contentType,
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    debugPrint('API UPLOAD: $url');

    final request = http.MultipartRequest('POST', url);

    // Add auth header if required
    if (requireAuth) {
      final token = await AuthService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Determine content type from filename if not provided
    final mimeType = contentType ?? _getMimeType(filename);

    // Add the file
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('API response ${response.statusCode}: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded as Map<String, dynamic>;
      }

      final errorMessage = decoded is Map && decoded.containsKey('detail')
          ? decoded['detail']
          : 'Something went wrong. Please try again.';
      throw ApiException(errorMessage, response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('HTTP upload failed: $e');
      rethrow;
    }
  }

  /// Upload a file with additional form fields using multipart form data
  static Future<Map<String, dynamic>> uploadFileWithFields(
    String endpoint,
    List<int> fileBytes,
    String filename, {
    String fieldName = 'image',
    String? contentType,
    Map<String, String>? additionalFields,
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    debugPrint('API UPLOAD WITH FIELDS: $url');

    final request = http.MultipartRequest('POST', url);

    // Add auth header if required
    if (requireAuth) {
      final token = await AuthService.getAccessToken();
      debugPrint('Auth token present: ${token != null && token.isNotEmpty}');
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        throw ApiException('Not authenticated. Please log in again.', 401);
      }
    }

    // Determine content type from filename if not provided
    final mimeType = contentType ?? _getMimeType(filename);

    // Add the file
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));

    // Add additional form fields
    if (additionalFields != null) {
      request.fields.addAll(additionalFields);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('API response ${response.statusCode}: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded as Map<String, dynamic>;
      }

      final errorMessage = decoded is Map && decoded.containsKey('detail')
          ? decoded['detail']
          : 'Something went wrong. Please try again.';
      throw ApiException(errorMessage, response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('HTTP upload failed: $e');
      rethrow;
    }
  }

  /// Get MIME type from filename extension
  static String _getMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
