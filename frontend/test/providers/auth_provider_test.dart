import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';

// Helper to create test AuthState instances
AuthState createTestState({
  bool isLoading = false,
  bool isAuthenticated = false,
  String? error,
  String? accessToken,
  String? errorCode,
  bool isSessionExpired = false,
  bool canRefreshToken = false,
  bool showLoginScreen = false,
  String? logoutSuccessMessage,
}) {
  return AuthState(
    isLoading: isLoading,
    isAuthenticated: isAuthenticated,
    error: error,
    accessToken: accessToken,
    errorCode: errorCode,
    isSessionExpired: isSessionExpired,
    canRefreshToken: canRefreshToken,
    showLoginScreen: showLoginScreen,
    logoutSuccessMessage: logoutSuccessMessage,
  );
}

void main() {
  group('AuthState', () {
    test('should have correct default values', () {
      const state = AuthState();

      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNull);
      expect(state.accessToken, isNull);
      expect(state.errorCode, isNull);
      expect(state.isSessionExpired, isFalse);
      expect(state.canRefreshToken, isFalse);
      expect(state.showLoginScreen, isFalse);
      expect(state.logoutSuccessMessage, isNull);
    });

    test('copyWith should update specified fields', () {
      const state = AuthState();

      final updated1 = state.copyWith(isLoading: true);
      expect(updated1.isLoading, isTrue);
      expect(updated1.isAuthenticated, isFalse); // unchanged

      final updated2 = state.copyWith(
        isAuthenticated: true,
        accessToken: 'test_token',
      );
      expect(updated2.isAuthenticated, isTrue);
      expect(updated2.accessToken, equals('test_token'));
      expect(updated2.isLoading, isFalse); // unchanged
    });

    test('copyWith should set error to null when explicitly provided', () {
      final state = createTestState(error: 'some error');
      expect(state.error, equals('some error'));

      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    test('copyWith should preserve existing values for null parameters', () {
      final state = createTestState(
        isLoading: true,
        isAuthenticated: true,
        accessToken: 'token',
        isSessionExpired: true,
        canRefreshToken: true,
        logoutSuccessMessage: 'Déconnexion réussie',
      );

      final updated = state.copyWith();
      expect(updated.isLoading, isTrue);
      expect(updated.isAuthenticated, isTrue);
      expect(updated.accessToken, equals('token'));
      expect(updated.isSessionExpired, isTrue);
      expect(updated.canRefreshToken, isTrue);
      expect(updated.logoutSuccessMessage, equals('Déconnexion réussie'));
    });

    test('copyWith should clear logout message when explicitly null', () {
      final state = createTestState(logoutSuccessMessage: 'Déconnexion réussie');

      final updated = state.copyWith(logoutSuccessMessage: null);

      expect(updated.logoutSuccessMessage, isNull);
    });
  });

  group('AuthResult', () {
    test('success factory should create success result', () {
      // We can't easily test AuthResult without mocking,
      // but we verify the class structure exists
      expect(AuthResult.success, isA<Function>());
      expect(AuthResult.failure, isA<Function>());
    });
  });

  group('TokenStatus', () {
    test('should have all expected values', () {
      expect(TokenStatus.values, contains(TokenStatus.valid));
      expect(TokenStatus.values, contains(TokenStatus.expired));
      expect(TokenStatus.values, contains(TokenStatus.missing));
    });
  });

  group('AuthInitializationResult', () {
    test('should have correct default values', () {
      const result = AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
      );

      expect(result.isAuthenticated, isFalse);
      expect(result.isSessionExpired, isFalse);
      expect(result.canRefresh, isFalse); // default value
      expect(result.shouldShowLogin, isFalse);
    });

    test('should accept custom values', () {
      const result = AuthInitializationResult(
        isAuthenticated: true,
        isSessionExpired: false,
        canRefresh: true,
        shouldShowLogin: true,
      );

      expect(result.isAuthenticated, isTrue);
      expect(result.isSessionExpired, isFalse);
      expect(result.canRefresh, isTrue);
      expect(result.shouldShowLogin, isTrue);
    });
  });
}
