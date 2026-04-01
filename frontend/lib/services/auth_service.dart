import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_response.dart';
import '../utils/app_config.dart';
import '../utils/constants.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Maps backend error codes to user-friendly error messages in French
///
/// Internal API error messages (english) should remain as-is
/// User-facing error messages (french) should be returned to UI
///
/// For unknown error codes:
/// - Beta channel: returns backend message (if available) for diagnostics
/// - Release channel: returns generic French fallback for safety
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
    case ErrorCodes.invalidCredentials:
      return 'Identifiants incorrects. Veuillez réessayer.';
    case ErrorCodes.unauthorized:
      return 'Accès non autorisé';
    case ErrorCodes.internalError:
      return 'Une erreur interne est survenue. Veuillez réessayer plus tard.';
    default:
      // Unknown error code: channel-aware handling
      if (AppConfig.showUnknownBackendDetails && defaultMessage.isNotEmpty) {
        // Beta: show backend message for diagnostics
        return defaultMessage;
      }
      // Release: generic French fallback
      return 'Une erreur est survenue. Veuillez réessayer.';
  }
}

/// Result of a token refresh operation
class RefreshResult {
  final bool success;
  final String? error;
  final RefreshFailureType? failureType;
  final AuthResponse? authResponse;

  const RefreshResult._({
    required this.success,
    this.error,
    this.failureType,
    this.authResponse,
  });

  factory RefreshResult.success({required AuthResponse authResponse}) {
    return RefreshResult._(
      success: true,
      authResponse: authResponse,
    );
  }

  factory RefreshResult.failure({
    required String error,
    required RefreshFailureType failureType,
  }) {
    return RefreshResult._(
      success: false,
      error: error,
      failureType: failureType,
    );
  }
}

/// Types of refresh failures for differentiated handling
enum RefreshFailureType {
  /// Refresh token is invalid or expired - requires re-authentication
  invalidToken,

  /// Transient network/transport failure - retry possible
  transientNetwork,

  /// Storage failure during token persistence
  storageFailure,
}

/// Authentication service handling all auth-related operations
///
/// Responsibilities:
/// - Server validation
/// - User registration
/// - Token management and validation
/// - Token refresh with single-flight control
/// - Logout
class AuthService {
  // Single-flight refresh control - shared across concurrent requests
  Future<RefreshResult>? _ongoingRefresh;

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

        // Save tokens and expiration dates
        await SecureStorageService.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          accessTokenExpires: authResponse.accessTokenExpires,
          refreshTokenExpires: authResponse.refreshTokenExpires,
        );
        await SecureStorageService.saveServerUrl(serverUrl);

        return AuthResult.success(authResponse: authResponse);
      } else {
        return AuthResult.failure(
          error:
              'Erreur inattendue (${response.statusCode}). Veuillez réessayer.',
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
            error:
                'Erreur serveur (${e.response?.statusCode}). Veuillez réessayer.',
          );
        }
      }
      return AuthResult.failure(
        error:
            'Erreur de connexion. Veuillez vérifier votre connexion internet et réessayer.',
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
      );
    }
  }

  /// Login with existing credentials
  Future<AuthResult> login({
    required String serverUrl,
    required String username,
    required String password,
    required bool rememberUsername,
  }) async {
    ApiClient.initialize(serverUrl);

    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.login,
        data: {'username': username, 'password': password},
      );

      if (response.statusCode != 200) {
        return AuthResult.failure(
          error:
              'Erreur inattendue (${response.statusCode}). Veuillez réessayer.',
        );
      }

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Save auth data with error handling - don't fail login if preference storage fails
      try {
        await SecureStorageService.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          accessTokenExpires: authResponse.accessTokenExpires,
          refreshTokenExpires: authResponse.refreshTokenExpires,
        );
        await SecureStorageService.saveServerUrl(serverUrl);
      } catch (e) {
        // Critical storage failure - tokens/server URL are required
        debugPrint('Failed to save critical auth data: $e');
        return AuthResult.failure(
          error:
              'Erreur lors de la sauvegarde des données. Veuillez réessayer.',
        );
      }

      // Save remember username preference (non-critical)
      try {
        await SecureStorageService.saveRememberUsernamePreference(
          rememberUsername,
        );
        if (rememberUsername) {
          await SecureStorageService.saveRememberedUsername(username);
        } else {
          await SecureStorageService.deleteRememberedUsername();
        }
      } catch (e) {
        // Log but don't fail - preference storage is nice-to-have
        debugPrint('Failed to save remember username preference: $e');
      }

      return AuthResult.success(authResponse: authResponse);
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
            error:
                'Erreur serveur (${e.response?.statusCode}). Veuillez réessayer.',
          );
        }
      }

      return AuthResult.failure(
        error:
            "Impossible de joindre le serveur. Vérifiez l'URL ou votre connexion, puis réessayez.",
      );
    } catch (_) {
      return AuthResult.failure(
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
      );
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

  /// Refresh the access token using the refresh token
  ///
  /// Implements single-flight pattern: concurrent calls will share
  /// the same refresh operation and await its result.
  ///
  /// Returns [RefreshResult.success] with new tokens on success,
  /// or [RefreshResult.failure] with error type for differentiated handling.
  Future<RefreshResult> refreshToken() async {
    // Single-flight pattern: if refresh is already in progress, await it
    if (_ongoingRefresh != null) {
      return _ongoingRefresh!;
    }

    // Start new refresh operation and store it
    _ongoingRefresh = _performRefresh();

    try {
      final result = await _ongoingRefresh!;
      return result;
    } finally {
      // Clear the ongoing refresh when done (success or failure)
      _ongoingRefresh = null;
    }
  }

  /// Internal refresh implementation
  Future<RefreshResult> _performRefresh() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      return RefreshResult.failure(
        error: 'Session expirée. Veuillez vous reconnecter.',
        failureType: RefreshFailureType.invalidToken,
      );
    }

    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Persist new tokens atomically
        try {
          await SecureStorageService.saveTokens(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            accessTokenExpires: authResponse.accessTokenExpires,
            refreshTokenExpires: authResponse.refreshTokenExpires,
          );

          return RefreshResult.success(authResponse: authResponse);
        } catch (e) {
          // Storage failure - clear tokens to avoid corrupted state
          debugPrint('Failed to persist refreshed tokens: $e');
          await SecureStorageService.deleteTokens();
          return RefreshResult.failure(
            error: 'Session expirée. Veuillez vous reconnecter.',
            failureType: RefreshFailureType.storageFailure,
          );
        }
      } else {
        return RefreshResult.failure(
          error: 'Session expirée. Veuillez vous reconnecter.',
          failureType: RefreshFailureType.invalidToken,
        );
      }
    } on DioException catch (e) {
      // Classify failure type for differentiated handling
      final failureType = _classifyRefreshFailure(e);
      final errorMessage = failureType == RefreshFailureType.invalidToken
          ? 'Session expirée. Veuillez vous reconnecter.'
          : 'Erreur de connexion. Veuillez réessayer.';

      return RefreshResult.failure(
        error: errorMessage,
        failureType: failureType,
      );
    } catch (e) {
      debugPrint('Unexpected error during token refresh: $e');
      return RefreshResult.failure(
        error: 'Erreur de connexion. Veuillez réessayer.',
        failureType: RefreshFailureType.transientNetwork,
      );
    }
  }

  /// Classify DioException into refresh failure type
  RefreshFailureType _classifyRefreshFailure(DioException e) {
    // Check for explicit auth errors from backend
    if (e.response?.data != null) {
      try {
        final errorData = e.response!.data as Map<String, dynamic>;
        final code = errorData['code'] as String?;
        if (code == ErrorCodes.invalidRefreshToken) {
          return RefreshFailureType.invalidToken;
        }
      } catch (_) {
        // Ignore parsing errors
      }
    }

    // Network/transport errors are transient
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return RefreshFailureType.transientNetwork;
      case DioExceptionType.badResponse:
        // 401 or 400 with invalid token = auth failure
        if (e.response?.statusCode == 401 ||
            (e.response?.statusCode == 400 &&
             e.response?.data['code'] == ErrorCodes.invalidRefreshToken)) {
          return RefreshFailureType.invalidToken;
        }
        return RefreshFailureType.transientNetwork;
      default:
        return RefreshFailureType.transientNetwork;
    }
  }

  /// Check if the access token needs proactive refresh
  ///
  /// Returns true if token expires within [refreshWindow] (default 5 minutes)
  /// with optional [clockSkewTolerance] (default 30 seconds) for device clock drift.
  Future<bool> needsProactiveRefresh({
    Duration refreshWindow = const Duration(minutes: 5),
    Duration clockSkewTolerance = const Duration(seconds: 30),
  }) async {
    final authResponse = await _getStoredAuthResponse();
    if (authResponse == null) return false;

    final totalWindow = refreshWindow + clockSkewTolerance;
    return authResponse.isAccessTokenExpiringSoon(window: totalWindow);
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

  Future<String?> getRememberedUsername() async {
    return await SecureStorageService.getRememberedUsername();
  }

  Future<bool> getRememberUsernamePreference() async {
    return await SecureStorageService.getRememberUsernamePreference();
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
    final rememberedUsername =
        await SecureStorageService.getRememberedUsername();
    final hasRememberedUsername =
        rememberedUsername != null && rememberedUsername.isNotEmpty;

    if (serverUrl == null) {
      return const AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
        shouldShowLogin: false,
      );
    }

    ApiClient.initialize(serverUrl);

    // Check token status
    final tokenStatus = await validateAccessToken();
    if (tokenStatus == TokenStatus.valid) {
      return const AuthInitializationResult(
        isAuthenticated: true,
        isSessionExpired: false,
        shouldShowLogin: true,
      );
    } else if (tokenStatus == TokenStatus.expired) {
      // Token exists but is expired
      final canRefresh = await canRefreshToken();
      return AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: true,
        canRefresh: canRefresh,
        shouldShowLogin: true,
      );
    }

    final hasRefreshToken = await getRefreshToken() != null;
    final shouldShowLogin = hasRememberedUsername || hasRefreshToken;

    return AuthInitializationResult(
      isAuthenticated: false,
      isSessionExpired: false,
      shouldShowLogin: shouldShowLogin,
    );
  }

  /// Get stored auth response with expiration dates
  Future<AuthResponse?> _getStoredAuthResponse() async {
    final accessToken = await SecureStorageService.getAccessToken();
    final refreshToken = await SecureStorageService.getRefreshToken();
    final accessTokenExpires =
        await SecureStorageService.getAccessTokenExpires();
    final refreshTokenExpires =
        await SecureStorageService.getRefreshTokenExpires();

    if (accessToken == null ||
        refreshToken == null ||
        accessTokenExpires == null ||
        refreshTokenExpires == null) {
      return null;
    }

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpires: accessTokenExpires,
      refreshTokenExpires: refreshTokenExpires,
    );
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

  /// True when unauthenticated users should enter from login screen
  final bool shouldShowLogin;

  const AuthInitializationResult({
    required this.isAuthenticated,
    required this.isSessionExpired,
    this.canRefresh = false,
    this.shouldShowLogin = false,
  });
}
