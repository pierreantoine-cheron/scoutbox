import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/auth_service.dart';

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
