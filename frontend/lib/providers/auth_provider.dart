import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';

part 'auth_provider.g.dart';

/// Provider for AuthService to enable dependency injection and testing
@riverpod
AuthService authService(Ref ref) => AuthService();

@riverpod
class AuthNotifier extends _$AuthNotifier {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    return const AuthState();
  }

  Future<void> register({
    required String serverUrl,
    required String inviteCode,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // First validate server is reachable
      final isReachable = await _authService.validateServer(serverUrl);
      if (!isReachable) {
        state = state.copyWith(
          isLoading: false,
          error: "Serveur inaccessible. Vérifiez l'URL ou la connexion réseau.",
        );
        return;
      }

      final result = await _authService.register(
        serverUrl: serverUrl,
        inviteCode: inviteCode,
        username: username,
        password: password,
      );

      if (result.success) {
        // Initialize API client with auth interceptors
        _initializeApiClientWithAuth(serverUrl);

        // Tokens are already saved by AuthService.register()
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          accessToken: result.authResponse!.accessToken,
          error: null,
        );
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      // Generic error message without exposing exception details to UI
      // Technical details should be logged, not shown to users
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
      );
    }
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
    required bool rememberUsername,
  }) async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null, errorCode: null);

    try {
      final result = await _authService.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
        rememberUsername: rememberUsername,
      );

      if (result.success) {
        // Initialize API client with auth interceptors
        _initializeApiClientWithAuth(serverUrl);

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          accessToken: result.authResponse!.accessToken,
          error: null,
          errorCode: null,
          showLoginScreen: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
          errorCode: result.code,
          isAuthenticated: false,
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  Future<void> checkAuthStatus() async {
    final initResult = await _authService.initializeFromStorage();

    if (initResult.isAuthenticated) {
      final token = await _authService.getAccessToken();
      state = state.copyWith(
        isAuthenticated: true,
        accessToken: token,
        isSessionExpired: false,
        showLoginScreen: true,
      );
    } else if (initResult.isSessionExpired) {
      state = state.copyWith(
        isAuthenticated: false,
        isSessionExpired: true,
        canRefreshToken: initResult.canRefresh,
        showLoginScreen: true,
      );
    } else {
      state = state.copyWith(
        isAuthenticated: false,
        isSessionExpired: false,
        showLoginScreen: initResult.shouldShowLogin,
      );
    }
  }

  /// Check if current session is valid, or if token needs refresh
  Future<void> validateSession() async {
    final isAuthenticated = await _authService.isAuthenticated();
    final isSessionExpired = await _authService.isSessionExpired();

    if (!isAuthenticated && isSessionExpired) {
      final canRefresh = await _authService.canRefreshToken();
      state = state.copyWith(
        isAuthenticated: false,
        isSessionExpired: true,
        canRefreshToken: canRefresh,
      );
    } else if (!isAuthenticated) {
      state = state.copyWith(isAuthenticated: false, isSessionExpired: false);
    }
    // If authenticated, state is already correct
  }

  /// Attempt to restore session by refreshing the token
  ///
  /// Called on startup when access token is expired but refresh token is valid.
  /// Returns true if session was successfully restored.
  Future<bool> attemptSessionRestoration() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.refreshToken();

      if (result.success && result.authResponse != null) {
        // Session restored - initialize API client with auth
        final serverUrl = await _authService.getServerUrl();
        if (serverUrl == null) {
          // Critical error: can't make API calls without server URL
          // Clear tokens but preserve server URL and remembered username
          try {
            await _authService.clearAuthTokensOnly();
          } catch (e) {
            debugPrint(
              'Clear auth tokens failed during null serverUrl handling: $e',
            );
          }
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: false,
            isSessionExpired: true,
            error: 'Erreur de configuration. Veuillez vous reconnecter.',
            showLoginScreen: true,
          );
          return false;
        }
        _initializeApiClientWithAuth(serverUrl);

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          isSessionExpired: false,
          accessToken: result.authResponse!.accessToken,
          error: null,
          showLoginScreen: true,
        );
        return true;
      } else {
        // Check if this is an unrecoverable auth failure
        if (result.failureType == RefreshFailureType.invalidToken) {
          // Clear auth tokens but preserve server URL and remembered username
          try {
            await _authService.clearAuthTokensOnly();
          } catch (e) {
            debugPrint(
              'Clear auth tokens failed during invalid token handling: $e',
            );
          }

          state = state.copyWith(
            isLoading: false,
            isAuthenticated: false,
            isSessionExpired: false,
            canRefreshToken: false,
            error: result.error,
            showLoginScreen: true,
          );
        } else {
          // Transient failure - don't force logout, keep session state
          state = state.copyWith(
            isLoading: false,
            error: result.error,
            canRefreshToken: true,
          );
        }
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de connexion. Veuillez réessayer.',
      );
      return false;
    }
  }

  /// Handle app resume from background - check token freshness
  ///
  /// Should be called from AppLifecycleState.resume handler.
  /// Returns true if session is valid or was refreshed.
  Future<bool> handleAppResume() async {
    final isAuthenticated = await _authService.isAuthenticated();

    if (isAuthenticated) {
      // Token still valid, nothing to do
      return true;
    }

    final isSessionExpired = await _authService.isSessionExpired();
    final canRefresh = await _authService.canRefreshToken();

    if (isSessionExpired && canRefresh) {
      // Try to refresh
      return await attemptSessionRestoration();
    }

    if (isSessionExpired && !canRefresh) {
      // Session expired and cannot refresh - transition to logged out
      try {
        await logout();
      } catch (e) {
        debugPrint('Logout failed during app resume: $e');
      }
      state = state.copyWith(
        isSessionExpired: true,
        canRefreshToken: false,
        showLoginScreen: true,
        error: 'Session expirée. Veuillez vous reconnecter.',
      );
      return false;
    }

    return false;
  }

  /// Initialize the API client with authentication interceptors
  void _initializeApiClientWithAuth(String serverUrl) {
    ApiClient.initializeWithAuth(
      serverUrl,
      getToken: () => _authService.getAccessToken(),
      needsRefresh: () => _authService.needsProactiveRefresh(),
      performRefresh: () async {
        return await _authService.refreshToken();
      },
      onAuthFailure: (failureType) {
        if (failureType == RefreshFailureType.invalidToken) {
          // Clear auth tokens but preserve server URL and remembered username
          _authService.clearAuthTokensOnly().catchError((e) {
            debugPrint('Clear auth tokens failed during auth failure: $e');
          });
          state = state.copyWith(
            isAuthenticated: false,
            isSessionExpired: true,
            canRefreshToken: false,
            showLoginScreen: true,
            error: 'Session expirée. Veuillez vous reconnecter.',
          );
        }
        // For transient failures: don't change state, let user retry
      },
    );
  }

  /// Enhanced checkAuthStatus that attempts session restoration
  Future<void> initializeAuth() async {
    try {
      final initResult = await _authService.initializeFromStorage();

      if (initResult.isAuthenticated) {
        // Valid access token - initialize with auth
        final serverUrl = await _authService.getServerUrl();
        if (serverUrl != null) {
          _initializeApiClientWithAuth(serverUrl);
        }

        final token = await _authService.getAccessToken();
        state = state.copyWith(
          isAuthenticated: true,
          accessToken: token,
          isSessionExpired: false,
          showLoginScreen: true,
        );
      } else if (initResult.isSessionExpired && initResult.canRefresh) {
        // Access token expired but refresh token valid - try to restore
        await attemptSessionRestoration();
        // attemptSessionRestoration already handles state updates
      } else {
        // No valid session
        state = state.copyWith(
          isAuthenticated: false,
          isSessionExpired: false,
          showLoginScreen: initResult.shouldShowLogin,
        );
      }
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
      state = state.copyWith(
        isAuthenticated: false,
        isSessionExpired: false,
        showLoginScreen: true,
        error: "Erreur d'initialisation. Veuillez redémarrer l'application.",
      );
    }
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? accessToken;
  final String? errorCode;

  /// True if the user was previously authenticated but the session expired
  final bool isSessionExpired;

  /// True if the refresh token exists and can be used to restore the session
  final bool canRefreshToken;

  /// True when unauthenticated users should land on login first
  final bool showLoginScreen;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.accessToken,
    this.errorCode,
    this.isSessionExpired = false,
    this.canRefreshToken = false,
    this.showLoginScreen = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    String? accessToken,
    String? errorCode,
    bool? isSessionExpired,
    bool? canRefreshToken,
    bool? showLoginScreen,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      accessToken: accessToken ?? this.accessToken,
      errorCode: errorCode,
      isSessionExpired: isSessionExpired ?? this.isSessionExpired,
      canRefreshToken: canRefreshToken ?? this.canRefreshToken,
      showLoginScreen: showLoginScreen ?? this.showLoginScreen,
    );
  }
}
