import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_config.dart';
import '../utils/constants.dart';
import 'auth_service.dart' show RefreshResult, RefreshFailureType;

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
  static bool _hasAuthInterceptors = false;

  // Single-flight refresh task shared by all concurrent requests
  static Future<RefreshResult>? _ongoingRefresh;

  // Excluded paths that should never trigger refresh or have auth headers
  static final _authExcludedPaths = [
    ApiRoutes.login,
    ApiRoutes.register,
    ApiRoutes.refresh,
    ApiRoutes.health,
  ];

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
    _hasAuthInterceptors = false;
  }

  /// Initialize with auth interceptors for authenticated requests
  static void initializeWithAuth(
    String baseUrl, {
    required Future<String?> Function() getToken,
    required Future<bool> Function() needsRefresh,
    required Future<RefreshResult> Function() performRefresh,
    required void Function(RefreshFailureType?) onAuthFailure,
  }) {
    // Guard against reinitializing with same URL
    if (_dio != null && _baseUrl == baseUrl && _hasAuthInterceptors) {
      return;
    }

    _baseUrl = baseUrl;
    _dio = _createDioWithAuth(
      baseUrl,
      getToken: getToken,
      needsRefresh: needsRefresh,
      performRefresh: performRefresh,
      onAuthFailure: onAuthFailure,
    );
    _hasAuthInterceptors = true;
  }

  /// Update the base URL (e.g., when user changes server)
  static void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = _createDio(baseUrl);
    _hasAuthInterceptors = false;
  }

  /// Dispose and recreate the client (useful for testing)
  static void reset() {
    _dio = null;
    _baseUrl = null;
    _hasAuthInterceptors = false;
    _ongoingRefresh = null;
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

    // Add logging interceptor in debug mode or beta channel
    if (kDebugMode || AppConfig.enableHttpLogging) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, error: true),
      );
    }

    return dio;
  }

  static Dio _createDioWithAuth(
    String baseUrl, {
    required Future<String?> Function() getToken,
    required Future<bool> Function() needsRefresh,
    required Future<RefreshResult> Function() performRefresh,
    required void Function(RefreshFailureType?) onAuthFailure,
  }) {
    final dio = _createDio(baseUrl);

    // Add auth interceptor for token attachment and refresh
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip auth for excluded paths
          if (_isAuthExcluded(options.path)) {
            return handler.next(options);
          }

          bool shouldRefresh = false;
          try {
            shouldRefresh = await needsRefresh();
          } catch (e) {
            debugPrint('Needs-refresh check failed, continuing request: $e');
          }

          if (shouldRefresh) {
            try {
              final result = await _runRefreshSingleFlight(performRefresh);
              if (!result.success && result.failureType == RefreshFailureType.invalidToken) {
                // Only trigger auth failure for invalid token, not transient errors
                onAuthFailure(result.failureType);
              }
              // For transient failures: don't trigger onAuthFailure
              // Request will proceed with current token
            } catch (e) {
              debugPrint('Proactive refresh failed, continuing request: $e');
            }
          }

          try {
            final token = await getToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              return handler.next(options);
            }
          } catch (e) {
            debugPrint('Token read failed in auth interceptor: $e');
          }

          // No token available - reject request
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              message: 'No authentication token available',
            ),
          );
        },
        onError: (error, handler) async {
          // Skip error handling for excluded paths
          if (_isAuthExcluded(error.requestOptions.path)) {
            return handler.next(error);
          }

          // Only handle 401 Unauthorized
          if (error.response?.statusCode != 401) {
            return handler.next(error);
          }

          // Prevent recursive refresh attempts
          if (error.requestOptions.extra['retryAfterRefresh'] == true) {
            onAuthFailure(RefreshFailureType.invalidToken);
            return handler.next(error);
          }

          // Attempt refresh
          try {
            final result = await _runRefreshSingleFlight(performRefresh);

            if (result.success) {
              // Retry original request with new token
              final token = await getToken();
              if (token != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
              }

              // Mark request to prevent infinite loops
              error.requestOptions.extra['retryAfterRefresh'] = true;

              // Retry the request
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } else if (result.failureType == RefreshFailureType.invalidToken) {
              // Invalid token - trigger auth failure
              onAuthFailure(result.failureType);
              return handler.next(error);
            } else {
              // Transient failure - don't force logout, just fail this request
              // User can retry manually
              return handler.next(error);
            }
          } catch (e) {
            debugPrint('Error during refresh and retry: $e');
            // Treat unexpected errors as transient - don't force logout
            return handler.next(error);
          }
        },
      ),
    );

    return dio;
  }

  /// Check if a path is excluded from auth handling
  ///
  /// Uses prefix matching with boundary check to prevent security bypass.
  /// A path like /api/auth/loginMalicious will NOT match /api/auth/login.
  static bool _isAuthExcluded(String path) {
    return _authExcludedPaths.any((excluded) {
      if (!path.startsWith(excluded)) return false;
      if (path.length == excluded.length) return true;
      // Allow trailing slash or path segment separator
      return path[excluded.length] == '/';
    });
  }

  static Future<RefreshResult> _runRefreshSingleFlight(
    Future<RefreshResult> Function() performRefresh,
  ) {
    if (_ongoingRefresh != null) {
      return _ongoingRefresh!;
    }

    final refreshFuture = performRefresh();
    _ongoingRefresh = refreshFuture;

    return refreshFuture.whenComplete(() {
      // Only clear if we still own the slot — reset() might have started a
      // new refresh in a different generation
      if (identical(_ongoingRefresh, refreshFuture)) {
        _ongoingRefresh = null;
      }
    });
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
