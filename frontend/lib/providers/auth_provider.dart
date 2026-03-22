import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/auth_service.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  late final AuthService _authService;
  
  @override
  AuthState build() {
    _authService = AuthService();
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
        // Save tokens and server URL
        await _authService.saveTokens(result.accessToken!, result.refreshToken!);
        await _authService.saveServerUrl(serverUrl);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          accessToken: result.accessToken,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur est survenue: $e',
      );
    }
  }
  
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }
  
  Future<void> checkAuthStatus() async {
    final token = await _authService.getAccessToken();
    if (token != null) {
      state = state.copyWith(isAuthenticated: true, accessToken: token);
    }
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? accessToken;
  
  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.accessToken,
  });
  
  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    String? accessToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
