import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/constants.dart';

/// Centralized API client with Dio configuration
///
/// This class provides a singleton Dio instance configured with:
/// - Base URL from storage
/// - Default timeouts
/// - Content-Type headers
/// - Interceptors for logging and auth tokens
class ApiClient {
  static Dio? _dio;
  static String? _baseUrl;

  /// Get the configured Dio instance
  static Dio get instance {
    if (_dio == null) {
      throw StateError(
        'ApiClient not initialized. Call ApiClient.initialize() first.',
      );
    }
    return _dio!;
  }

  /// Initialize the API client with a base URL
  static void initialize(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = _createDio(baseUrl);
  }

  /// Update the base URL (e.g., when user changes server)
  static void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = _createDio(baseUrl);
  }

  /// Dispose and recreate the client (useful for testing)
  static void reset() {
    _dio = null;
    _baseUrl = null;
  }

  static Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiTimeouts.defaultTimeout,
        receiveTimeout: ApiTimeouts.defaultTimeout,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );

    // Add logging interceptor in debug mode
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );

    return dio;
  }

  /// Create a temporary Dio instance for health checks
  /// This doesn't use the singleton and has shorter timeouts
  static Dio createHealthCheckClient(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiTimeouts.healthCheck,
        receiveTimeout: ApiTimeouts.healthCheck,
      ),
    );
  }

  /// Get the current base URL
  static String? get baseUrl => _baseUrl;
}
