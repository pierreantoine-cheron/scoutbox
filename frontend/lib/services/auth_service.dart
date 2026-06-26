import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_response.dart';
import '../models/invite_response.dart';
import '../utils/app_config.dart';
import '../utils/constants.dart';
import '../utils/design_constants.dart';
import '../repositories/auth_repository.dart';
import 'api_client.dart';
import 'error_localizer.dart';
import 'secure_storage_service.dart';

/// Maps backend error codes to user-friendly error messages in French
///
/// Internal API error messages (english) should remain as-is
/// User-facing error messages (french) should be returned to UI
///
/// Localized via ErrorLocalizer — one central source of truth.

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
    return RefreshResult._(success: true, authResponse: authResponse);
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
  final AuthRepository _authRepository = const AuthRepository();

  // Single-flight refresh control - shared across concurrent requests
  Future<RefreshResult>? _ongoingRefresh;

  // Keeps the latest access token available for immediate authenticated calls.
  String? _cachedAccessToken;

  // Caches the full auth response to avoid repeated secure-storage reads
  AuthResponse? _cachedAuthResponse;

  Future<void> _persistAuthResponse(
    AuthResponse authResponse, {
    String? serverUrl,
  }) async {
    await SecureStorageService.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      accessTokenExpires: authResponse.accessTokenExpires,
      refreshTokenExpires: authResponse.refreshTokenExpires,
    );
    if (serverUrl != null) {
      await SecureStorageService.saveServerUrl(serverUrl);
    }
    _cacheAuthResponse(authResponse);
  }

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
      final authResponse = await _authRepository.register(
        serverUrl: serverUrl,
        inviteCode: inviteCode,
        username: username,
        password: password,
      );

      await _persistAuthResponse(authResponse, serverUrl: serverUrl);

      return AuthResult.success(authResponse: authResponse);
    } on DioException catch (e) {
      return _mapDioExceptionToAuthResult(
        e,
        connectionErrorMessage:
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
      final authResponse = await _authRepository.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );

      // Save auth data with error handling - don't fail login if preference storage fails
      try {
        await _persistAuthResponse(authResponse, serverUrl: serverUrl);
      } catch (e) {
        // Critical storage failure - tokens/server URL are required
        debugPrint('Failed to save critical auth data: $e');
        return AuthResult.failure(
          error: 'Erreur lors de la sauvegarde des données. Veuillez réessayer.',
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
      return _mapDioExceptionToAuthResult(
        e,
        connectionErrorMessage:
            "Impossible de joindre le serveur. Vérifiez l'URL ou votre connexion, puis réessayez.",
      );
    } catch (_) {
      return AuthResult.failure(
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
      );
    }
  }

  /// Maps a [DioException] to an [AuthResult.failure] with appropriate user message
  AuthResult _mapDioExceptionToAuthResult(
    DioException e, {
    required String connectionErrorMessage,
  }) {
    if (e.response?.data != null) {
      try {
        final errorResponse = ErrorResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
        final userMessage = ErrorLocalizer.localize(
          errorResponse.code,
          fallback: errorResponse.error,
        );
        return AuthResult.failure(error: userMessage, code: errorResponse.code);
      } catch (_) {
        return AuthResult.failure(
          error: 'Erreur serveur (${e.response?.statusCode}). Veuillez réessayer.',
        );
      }
    }
    return AuthResult.failure(error: connectionErrorMessage);
  }

  ///
  /// Returns [TokenStatus.valid] if token exists and is not expired,
  /// [TokenStatus.expired] if token exists but is expired,
  /// [TokenStatus.missing] if no token exists.
  ///
  /// Uses clock skew tolerance to avoid false-expired decisions.
  Future<TokenStatus> validateAccessToken() async {
    try {
      final authResponse = await _getStoredAuthResponse();
      if (authResponse == null) {
        return TokenStatus.missing;
      }

      if (authResponse.isAccessTokenExpiredWithTolerance()) {
        return TokenStatus.expired;
      }

      return TokenStatus.valid;
    } catch (e) {
      debugPrint('Access token validation failed: $e');
      return TokenStatus.missing;
    }
  }

  /// Check if the refresh token is valid (not expired)
  ///
  /// Returns true if refresh token exists and is not expired.
  /// Uses clock skew tolerance to avoid false-expired decisions.
  Future<bool> canRefreshToken() async {
    try {
      final authResponse = await _getStoredAuthResponse();
      if (authResponse == null) {
        return false;
      }

      return !authResponse.isRefreshTokenExpiredWithTolerance();
    } catch (e) {
      debugPrint('Refresh token validation failed: $e');
      return false;
    }
  }

  /// Logout the current user
  ///
  /// Calls backend logout endpoint to revoke refresh token (best effort),
  /// then clears local auth tokens. Server URL and remembered username
  /// are preserved for next login.
  ///
  /// This method is resilient - local cleanup always happens even if
  /// backend logout fails.
  Future<void> logout() async {
    // Attempt to call backend logout (best effort)
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        await _callBackendLogout(refreshToken);
      }
    } catch (e) {
      // Backend logout failure is non-blocking
      // Local cleanup will still proceed
      debugPrint('Backend logout call failed: $e');
    }

    // Always clear local auth tokens (never leave stale auth state)
    await SecureStorageService.clearAuthTokens();
    _cachedAccessToken = null;
    _cachedAuthResponse = null;
    ApiClient.reset();
  }

  /// Call backend logout endpoint
  Future<void> _callBackendLogout(String refreshToken) async {
    try {
      await _authRepository.logout(refreshToken);
    } on DioException catch (e) {
      // Auth failures (401, 400 with invalid token) are expected
      // if token already expired or was revoked
      if (e.response?.statusCode == 401) {
        debugPrint('Backend logout: token already invalid (401)');
        return;
      }
      if (e.response?.statusCode == 400) {
        final data = e.response?.data as Map<String, dynamic>?;
        if (data?['code'] == ErrorCodes.invalidRefreshToken) {
          debugPrint('Backend logout: refresh token invalid (400)');
          return;
        }
      }
      // Re-throw other errors to be handled by caller
      rethrow;
    }
  }

  /// Clear auth tokens only, preserving server URL and remembered username
  ///
  /// Used when session expires but user should see prefilled login form.
  Future<void> clearAuthTokensOnly() async {
    await SecureStorageService.clearAuthTokens();
    _cachedAccessToken = null;
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
    // Read refresh token with storage error handling
    String? refreshToken;
    try {
      refreshToken = await getRefreshToken();
    } catch (e) {
      debugPrint('Failed to read refresh token from storage: $e');
      return RefreshResult.failure(
        error: AppConfig.isBetaChannel
            ? 'Erreur de lecture du token de rafraîchissement: $e'
            : 'Erreur de stockage. Veuillez réessayer.',
        failureType: RefreshFailureType.storageFailure,
      );
    }

    if (refreshToken == null) {
      return RefreshResult.failure(
        error: 'Session expirée. Veuillez vous reconnecter.',
        failureType: RefreshFailureType.invalidToken,
      );
    }

    try {
      final authResponse = await _authRepository.refreshToken(refreshToken);

      try {
        await _persistAuthResponse(authResponse);

        return RefreshResult.success(authResponse: authResponse);
      } catch (e) {
        // Storage failure - attempt to clear tokens to avoid corrupted state
        debugPrint('Failed to persist refreshed tokens: $e');
        _cachedAccessToken = null;
        try {
          await SecureStorageService.deleteTokens();
        } catch (deleteError) {
          debugPrint(
            'Failed to delete tokens after storage failure: $deleteError',
          );
          // Continue with failure result, don't cascade
        }
        return RefreshResult.failure(
          error: AppConfig.isBetaChannel
              ? 'Erreur de sauvegarde des tokens: $e'
              : 'Session expirée. Veuillez vous reconnecter.',
          failureType: RefreshFailureType.storageFailure,
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
        error: AppConfig.isBetaChannel
            ? 'Erreur inattendue lors du rafraîchissement: $e'
            : 'Erreur de connexion. Veuillez réessayer.',
        failureType: RefreshFailureType.transientNetwork,
      );
    }
  }

  /// Classify DioException into refresh failure type
  RefreshFailureType _classifyRefreshFailure(DioException e) {
    // Check for explicit auth errors from backend
    if (e.response?.data != null && e.response!.data is Map<String, dynamic>) {
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
        if (e.response?.statusCode == 401) {
          return RefreshFailureType.invalidToken;
        }
        if (e.response?.statusCode == 400 &&
            e.response?.data is Map<String, dynamic> &&
            e.response?.data['code'] == ErrorCodes.invalidRefreshToken) {
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
    Duration refreshWindow = DesignConstants.tokenRefreshWindow,
    Duration clockSkewTolerance = DesignConstants.clockSkewTolerance,
  }) async {
    try {
      final authResponse = await _getStoredAuthResponse();
      if (authResponse == null) return false;

      final totalWindow = refreshWindow + clockSkewTolerance;
      return authResponse.isAccessTokenExpiringSoon(window: totalWindow);
    } catch (e) {
      debugPrint('Proactive refresh check failed: $e');
      return false;
    }
  }

  /// Get the current access token
  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) {
      return _cachedAccessToken;
    }

    final accessToken = await SecureStorageService.getAccessToken();
    _cachedAccessToken = accessToken;
    return accessToken;
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

  Future<void> saveCurrentUsername(String username) async {
    await SecureStorageService.saveCurrentUsername(username);
  }

  Future<String?> getCurrentUsername() async {
    return await SecureStorageService.getCurrentUsername();
  }

  Future<InviteResponse> createInvite() async {
    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.invites,
        data: {'expiresInDays': 30},
      );
      return InviteResponse(
        id: response.data['id'] as String,
        code: response.data['code'] as String,
        expiresAt: DateTime.parse(response.data['expiresAt'] as String),
        isUsed: response.data['isUsed'] as bool,
        inviteLink: response.data['inviteLink'] as String?,
      );
    } catch (_) {
      throw Exception("Impossible de générer le code d'invitation. Réessayez.");
    }
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
    final rememberedUsername = await SecureStorageService.getRememberedUsername();
    final hasRememberedUsername = rememberedUsername != null && rememberedUsername.isNotEmpty;

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
      _cachedAccessToken = null;
      final canRefresh = await canRefreshToken();
      return AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: true,
        canRefresh: canRefresh,
        shouldShowLogin: true,
      );
    }

    _cachedAccessToken = null;

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
    if (_cachedAuthResponse != null) return _cachedAuthResponse;
    final accessToken = await SecureStorageService.getAccessToken();
    final refreshToken = await SecureStorageService.getRefreshToken();
    final accessTokenExpires = await SecureStorageService.getAccessTokenExpires();
    final refreshTokenExpires = await SecureStorageService.getRefreshTokenExpires();

    if (accessToken == null ||
        refreshToken == null ||
        accessTokenExpires == null ||
        refreshTokenExpires == null) {
      return null;
    }

    final response = AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpires: accessTokenExpires,
      refreshTokenExpires: refreshTokenExpires,
    );
    _cacheAuthResponse(response);
    return response;
  }

  void _cacheAuthResponse(AuthResponse response) {
    _cachedAuthResponse = response;
    _cachedAccessToken = response.accessToken;
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
