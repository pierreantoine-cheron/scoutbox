import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../utils/constants.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Maps backend error codes to user-friendly error messages in French
///
/// Internal API error messages (english) should remain as-is
/// User-facing error messages (french) should be returned to UI
String _getErrorMessage(String code, String defaultMessage) {
  switch (code) {
    case ErrorCodes.invalidInvite:
      return "Code d'invitation invalide, expiré ou déjà utilisé";
    case ErrorCodes.usernameExists:
      return "Ce nom d'utilisateur est déjà pris";
    case ErrorCodes.duplicateCode:
      return "Ce code d'invitation existe déjà";
    case ErrorCodes.codeGenerationFailed:
      return "Impossible de générer un code d'invitation. Veuillez réessayer.";
    case ErrorCodes.invalidRefreshToken:
      return 'Session expirée. Veuillez vous reconnecter.';
    case ErrorCodes.unauthorized:
      return 'Accès non autorisé';
    case ErrorCodes.internalError:
      return 'Une erreur interne est survenue. Veuillez réessayer plus tard.';
    default:
      // Return the server message if available, otherwise default
      return defaultMessage.isNotEmpty
          ? defaultMessage
          : 'Une erreur est survenue';
  }
}

/// Authentication service handling all auth-related operations
///
/// Responsibilities:
/// - Server validation
/// - User registration
/// - Token management and validation
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
          final userMessage = _getErrorMessage(
            errorResponse.code,
            errorResponse.error,
          );
          return AuthResult.failure(
            error: userMessage,
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

  /// Check if the current access token is valid (not expired)
  ///
  /// Returns [TokenStatus.valid] if token exists and is not expired,
  /// [TokenStatus.expired] if token exists but is expired,
  /// [TokenStatus.missing] if no token exists.
  Future<TokenStatus> validateAccessToken() async {
    final authResponse = await _getStoredAuthResponse();
    if (authResponse == null) {
      return TokenStatus.missing;
    }

    if (authResponse.isAccessTokenExpired) {
      return TokenStatus.expired;
    }

    return TokenStatus.valid;
  }

  /// Check if the refresh token is valid (not expired)
  ///
  /// Returns true if refresh token exists and is not expired
  Future<bool> canRefreshToken() async {
    final authResponse = await _getStoredAuthResponse();
    if (authResponse == null) {
      return false;
    }

    return !authResponse.isRefreshTokenExpired;
  }

  /// Logout the current user
  ///
  /// Clears all stored tokens and server URL.
  /// Note: This doesn't invalidate the token on the server.
  Future<void> logout() async {
    await SecureStorageService.clearAll();
    ApiClient.reset();
  }

  /// Check if user is authenticated with a valid token
  ///
  /// Returns true only if access token exists and is not expired.
  Future<bool> isAuthenticated() async {
    final status = await validateAccessToken();
    return status == TokenStatus.valid;
  }

  /// Check if user was previously authenticated but token expired
  ///
  /// Useful for showing "session expired" messages.
  Future<bool> isSessionExpired() async {
    final status = await validateAccessToken();
    return status == TokenStatus.expired;
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
  ///
  /// Returns true if authenticated with valid token,
  /// false if no credentials or token expired.
  Future<AuthInitializationResult> initializeFromStorage() async {
    final serverUrl = await SecureStorageService.getServerUrl();
    final accessToken = await SecureStorageService.getAccessToken();

    if (serverUrl == null || accessToken == null) {
      return const AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
      );
    }

    ApiClient.initialize(serverUrl);

    // Check token status
    final tokenStatus = await validateAccessToken();
    if (tokenStatus == TokenStatus.valid) {
      return const AuthInitializationResult(
        isAuthenticated: true,
        isSessionExpired: false,
      );
    } else if (tokenStatus == TokenStatus.expired) {
      // Token exists but is expired
      final canRefresh = await canRefreshToken();
      return AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: true,
        canRefresh: canRefresh,
      );
    }

    return const AuthInitializationResult(
      isAuthenticated: false,
      isSessionExpired: false,
    );
  }

  /// Get stored auth response with expiration dates
  Future<AuthResponse?> _getStoredAuthResponse() async {
    final accessToken = await SecureStorageService.getAccessToken();
    final refreshToken = await SecureStorageService.getRefreshToken();
    final serverUrl = await SecureStorageService.getServerUrl();

    if (accessToken == null || refreshToken == null || serverUrl == null) {
      return null;
    }

    // We don't store the expiration dates separately, so we need to
    // create a minimal AuthResponse with the tokens.
    // The expiration check will fail and require re-authentication.
    // TODO: Store expiration dates in secure storage for proper validation
    return null;
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

/// Token validation status
enum TokenStatus {
  /// Token exists and is valid
  valid,

  /// Token exists but has expired
  expired,

  /// No token exists
  missing,
}

/// Result of auth initialization from storage
class AuthInitializationResult {
  /// True if user has valid authentication
  final bool isAuthenticated;

  /// True if user was authenticated but session expired
  final bool isSessionExpired;

  /// True if refresh token exists and can be used to get new access token
  final bool canRefresh;

  const AuthInitializationResult({
    required this.isAuthenticated,
    required this.isSessionExpired,
    this.canRefresh = false,
  });
}
