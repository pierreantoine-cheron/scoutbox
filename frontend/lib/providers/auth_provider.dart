import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';
import '../models/auth_state.dart';
import '../models/invite_response.dart';
import 'app_bar_config_provider.dart';

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

  // Internal helpers for repeated state transitions

  /// Sets state to logged-out with success message (used after logout)
  void _setLoggedOutSuccessState() {
    ref.invalidate(appBarConfigProvider);
    state = const AuthState(
      isLoading: false,
      isAuthenticated: false,
      error: null,
      accessToken: null,
      errorCode: null,
      isSessionExpired: false,
      canRefreshToken: false,
      showLoginScreen: true,
      logoutSuccessMessage: 'Déconnexion réussie',
    );
  }

  /// Sets state to session-expired with optional error and refresh capability
  void _setSessionExpiredState({
    required bool canRefresh,
    String? error,
    bool clearAuth = false,
  }) {
    if (clearAuth) {
      _clearTokensOnFailure();
    }
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      isSessionExpired: true,
      canRefreshToken: canRefresh,
      showLoginScreen: true,
      error: error,
    );
  }

  /// Clears auth tokens on failure with error logging
  void _clearTokensOnFailure() {
    _authService.clearAuthTokensOnly().catchError((e) {
      debugPrint('Clear auth tokens failed: $e');
    });
  }

  void _setAuthenticatedState(String serverUrl, String accessToken) {
    _initializeApiClientWithAuth(serverUrl);
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      accessToken: accessToken,
      error: null,
      errorCode: null,
      isSessionExpired: false,
      showLoginScreen: true,
    );
  }

  Future<void> register({
    required String serverUrl,
    required String inviteCode,
    required String username,
    required String password,
  }) async {
    if (state.isLoading) {
      return;
    }

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
        // Tokens are already saved by AuthService.register()
        await _authService.saveCurrentUsername(username);
        _setAuthenticatedState(serverUrl, result.authResponse!.accessToken);
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

    state = state.copyWith(
      isLoading: true,
      error: null,
      errorCode: null,
      logoutSuccessMessage: null,
    );

    try {
      final result = await _authService.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
        rememberUsername: rememberUsername,
      );

      if (result.success) {
        await _authService.saveCurrentUsername(username);
        _setAuthenticatedState(serverUrl, result.authResponse!.accessToken);
        state = state.copyWith(logoutSuccessMessage: null);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
          errorCode: result.code,
          isAuthenticated: false,
          logoutSuccessMessage: null,
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur inattendue est survenue. Veuillez réessayer.',
        logoutSuccessMessage: null,
      );
    }
  }

  Future<void> logout() async {
    // Prevent duplicate logout submissions
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.logout();
      _setLoggedOutSuccessState();
    } catch (e) {
      // Even on error, clear auth state to ensure user is logged out locally
      debugPrint('Logout error: $e');
      _setLoggedOutSuccessState();
    }
  }

  /// Consume the logout success message (clears it from state)
  void consumeLogoutSuccessMessage() {
    state = state.copyWith(logoutSuccessMessage: null);
  }

  Future<InviteResponse> createInvite() async {
    return await _authService.createInvite();
  }

  void showLoginScreen() {
    state = state.copyWith(showLoginScreen: true, error: null, errorCode: null);
  }

  void showRegisterScreen() {
    state = state.copyWith(
      showLoginScreen: false,
      error: null,
      errorCode: null,
    );
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
          _clearTokensOnFailure();
          _setSessionExpiredState(
            canRefresh: true,
            error: 'Erreur de configuration. Veuillez vous reconnecter.',
          );
          return false;
        }
        _setAuthenticatedState(serverUrl, result.authResponse!.accessToken);
        return true;
      } else {
        // Check if this is an unrecoverable auth failure
        if (result.failureType == RefreshFailureType.invalidToken) {
          _clearTokensOnFailure();
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
            showLoginScreen: true,
          );
        }
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de connexion. Veuillez réessayer.',
        showLoginScreen: true,
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
      _setSessionExpiredState(
        canRefresh: false,
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
          _clearTokensOnFailure();
          _setSessionExpiredState(
            canRefresh: false,
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
