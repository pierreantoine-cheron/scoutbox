import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../utils/constants.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Authentication service handling all auth-related operations
///
/// Responsibilities:
/// - Server validation
/// - User registration
/// - Token management
/// - Logout
class AuthService {
  /// Validate that a server is reachable and has the health endpoint
  Future<bool> validateServer(String serverUrl) async {
    try {
      final dio = ApiClient.createHealthCheckClient(serverUrl);
      final response = await dio.get(ApiRoutes.health);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Register a new user with an invite code
  ///
  /// Returns [AuthResult.success] with tokens on success,
  /// or [AuthResult.failure] with an error message on failure.
  Future<AuthResult> register({
    required String serverUrl,
    required String inviteCode,
    required String username,
    required String password,
  }) async {
    // Initialize the API client with the server URL
    ApiClient.initialize(serverUrl);

    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.register,
        data: {
          'inviteCode': inviteCode,
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Save tokens and server URL
        await SecureStorageService.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
        );
        await SecureStorageService.saveServerUrl(serverUrl);

        return AuthResult.success(authResponse: authResponse);
      } else {
        return AuthResult.failure(
          error: 'Unexpected error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        try {
          final errorResponse = ErrorResponse.fromJson(
            e.response!.data as Map<String, dynamic>,
          );
          return AuthResult.failure(
            error: errorResponse.error,
            code: errorResponse.code,
          );
        } catch (_) {
          return AuthResult.failure(
            error: 'Server error: ${e.response?.statusCode}',
          );
        }
      }
      return AuthResult.failure(error: 'Connection error. Please try again.');
    } catch (e) {
      return AuthResult.failure(error: 'Unexpected error: $e');
    }
  }

  /// Logout the current user
  ///
  /// Clears all stored tokens and server URL.
  /// Note: This doesn't invalidate the token on the server.
  Future<void> logout() async {
    await SecureStorageService.clearAll();
    ApiClient.reset();
  }

  /// Check if user is authenticated
  ///
  /// Returns true if access token exists in secure storage.
  Future<bool> isAuthenticated() async {
    final token = await SecureStorageService.getAccessToken();
    return token != null;
  }

  /// Get the current access token
  Future<String?> getAccessToken() async {
    return await SecureStorageService.getAccessToken();
  }

  /// Get the current refresh token
  Future<String?> getRefreshToken() async {
    return await SecureStorageService.getRefreshToken();
  }

  /// Get the stored server URL
  Future<String?> getServerUrl() async {
    return await SecureStorageService.getServerUrl();
  }

  /// Initialize auth service from stored credentials
  ///
  /// Should be called on app startup to restore the API client
  /// with the stored server URL.
  Future<bool> initializeFromStorage() async {
    final serverUrl = await SecureStorageService.getServerUrl();
    final accessToken = await SecureStorageService.getAccessToken();

    if (serverUrl != null && accessToken != null) {
      ApiClient.initialize(serverUrl);
      return true;
    }

    return false;
  }
}

/// Result of an authentication operation
///
/// Use [AuthResult.success] constructor for successful operations,
/// [AuthResult.failure] for failed operations.
class AuthResult {
  final bool success;
  final String? error;
  final String? code;
  final AuthResponse? authResponse;

  const AuthResult._({
    required this.success,
    this.error,
    this.code,
    this.authResponse,
  });

  factory AuthResult.success({required AuthResponse authResponse}) {
    return AuthResult._(success: true, authResponse: authResponse);
  }

  factory AuthResult.failure({required String error, String? code}) {
    return AuthResult._(success: false, error: error, code: code);
  }
}
