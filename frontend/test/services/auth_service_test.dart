import 'package:flutter_test/flutter_test.dart';

import 'package:client/utils/constants.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/models/auth_response.dart';

void main() {
  group('AuthService Unit Tests', () {
    group('Constants', () {
      test('ErrorCodes have correct values', () {
        expect(ErrorCodes.invalidInvite, equals('INVALID_INVITE'));
        expect(ErrorCodes.usernameExists, equals('USERNAME_EXISTS'));
        expect(ErrorCodes.duplicateCode, equals('DUPLICATE_CODE'));
        expect(
          ErrorCodes.codeGenerationFailed,
          equals('CODE_GENERATION_FAILED'),
        );
        expect(ErrorCodes.invalidRefreshToken, equals('INVALID_REFRESH_TOKEN'));
        expect(ErrorCodes.invalidCredentials, equals('INVALID_CREDENTIALS'));
        expect(ErrorCodes.unauthorized, equals('UNAUTHORIZED'));
        expect(ErrorCodes.internalError, equals('INTERNAL_ERROR'));
      });

      test('ValidationConstants match backend constraints', () {
        expect(ValidationConstants.usernameMinLength, equals(3));
        expect(ValidationConstants.usernameMaxLength, equals(50));
        expect(ValidationConstants.passwordMinLength, equals(8));
        expect(ValidationConstants.inviteCodeMaxLength, equals(64));
      });

      test('ApiRoutes are correctly defined', () {
        expect(ApiRoutes.health, equals('/api/health'));
        expect(ApiRoutes.authBase, equals('/api/auth'));
        expect(ApiRoutes.register, equals('/api/auth/register'));
        expect(ApiRoutes.login, equals('/api/auth/login'));
        expect(ApiRoutes.refresh, equals('/api/auth/refresh'));
        expect(ApiRoutes.invites, equals('/api/auth/invites'));
        expect(ApiRoutes.logout, equals('/api/auth/logout'));
      });

      test('StorageKeys are correctly defined', () {
        expect(StorageKeys.accessToken, equals('access_token'));
        expect(StorageKeys.refreshToken, equals('refresh_token'));
        expect(StorageKeys.serverUrl, equals('server_url'));
        expect(StorageKeys.rememberUsername, equals('remember_username'));
        expect(StorageKeys.rememberedUsername, equals('remembered_username'));
        expect(StorageKeys.accessTokenExpires, equals('access_token_expires'));
        expect(
          StorageKeys.refreshTokenExpires,
          equals('refresh_token_expires'),
        );
      });

      test('ApiTimeouts have correct durations', () {
        expect(ApiTimeouts.healthCheck, equals(const Duration(seconds: 5)));
        expect(ApiTimeouts.defaultTimeout, equals(const Duration(seconds: 10)));
        expect(ApiTimeouts.longTimeout, equals(const Duration(seconds: 30)));
      });
    });

    group('RefreshFailureType', () {
      test('RefreshFailureType enum values exist', () {
        expect(RefreshFailureType.values.length, equals(3));
        expect(
          RefreshFailureType.values,
          contains(RefreshFailureType.invalidToken),
        );
        expect(
          RefreshFailureType.values,
          contains(RefreshFailureType.transientNetwork),
        );
        expect(
          RefreshFailureType.values,
          contains(RefreshFailureType.storageFailure),
        );
      });
    });

    group('RefreshResult', () {
      test('RefreshResult.success creates success result', () {
        final now = DateTime.now();
        final authResponse = AuthResponse(
          accessToken: 'test_access',
          refreshToken: 'test_refresh',
          accessTokenExpires: now.add(const Duration(minutes: 15)),
          refreshTokenExpires: now.add(const Duration(days: 180)),
        );

        final result = RefreshResult.success(authResponse: authResponse);

        expect(result.success, isTrue);
        expect(result.authResponse, equals(authResponse));
        expect(result.error, isNull);
        expect(result.failureType, isNull);
      });

      test(
        'RefreshResult.failure creates failure result with invalidToken type',
        () {
          final result = RefreshResult.failure(
            error: 'Session expirée. Veuillez vous reconnecter.',
            failureType: RefreshFailureType.invalidToken,
          );

          expect(result.success, isFalse);
          expect(
            result.error,
            equals('Session expirée. Veuillez vous reconnecter.'),
          );
          expect(result.failureType, equals(RefreshFailureType.invalidToken));
          expect(result.authResponse, isNull);
        },
      );

      test(
        'RefreshResult.failure creates failure result with transientNetwork type',
        () {
          final result = RefreshResult.failure(
            error: 'Erreur de connexion. Veuillez réessayer.',
            failureType: RefreshFailureType.transientNetwork,
          );

          expect(result.success, isFalse);
          expect(
            result.failureType,
            equals(RefreshFailureType.transientNetwork),
          );
        },
      );

      test(
        'RefreshResult.failure creates failure result with storageFailure type',
        () {
          final result = RefreshResult.failure(
            error: 'Session expirée. Veuillez vous reconnecter.',
            failureType: RefreshFailureType.storageFailure,
          );

          expect(result.success, isFalse);
          expect(result.failureType, equals(RefreshFailureType.storageFailure));
        },
      );

      test('RefreshResult.storageFailure has appropriate error message', () {
        final result = RefreshResult.failure(
          error: 'Erreur de stockage. Veuillez réessayer.',
          failureType: RefreshFailureType.storageFailure,
        );

        expect(result.success, isFalse);
        expect(result.failureType, equals(RefreshFailureType.storageFailure));
        expect(result.error, contains('stockage'));
      });
    });

    group('AuthResult', () {
      test('AuthResult.success creates success result', () {
        final now = DateTime.now();
        final authResponse = AuthResponse(
          accessToken: 'test_access',
          refreshToken: 'test_refresh',
          accessTokenExpires: now.add(const Duration(minutes: 15)),
          refreshTokenExpires: now.add(const Duration(days: 180)),
        );

        final result = AuthResult.success(authResponse: authResponse);

        expect(result.success, isTrue);
        expect(result.authResponse, equals(authResponse));
        expect(result.error, isNull);
        expect(result.code, isNull);
      });

      test('AuthResult.failure creates failure result', () {
        final result = AuthResult.failure(
          error: 'Identifiants incorrects',
          code: ErrorCodes.invalidCredentials,
        );

        expect(result.success, isFalse);
        expect(result.error, equals('Identifiants incorrects'));
        expect(result.code, equals(ErrorCodes.invalidCredentials));
        expect(result.authResponse, isNull);
      });
    });

    group('AuthInitializationResult', () {
      test('AuthInitializationResult with all defaults', () {
        const result = AuthInitializationResult(
          isAuthenticated: false,
          isSessionExpired: false,
        );

        expect(result.isAuthenticated, isFalse);
        expect(result.isSessionExpired, isFalse);
        expect(result.canRefresh, isFalse);
        expect(result.shouldShowLogin, isFalse);
      });

      test('AuthInitializationResult with canRefresh true', () {
        const result = AuthInitializationResult(
          isAuthenticated: false,
          isSessionExpired: true,
          canRefresh: true,
          shouldShowLogin: true,
        );

        expect(result.isAuthenticated, isFalse);
        expect(result.isSessionExpired, isTrue);
        expect(result.canRefresh, isTrue);
        expect(result.shouldShowLogin, isTrue);
      });
    });

    group('TokenStatus', () {
      test('TokenStatus enum values exist', () {
        expect(TokenStatus.values.length, equals(3));
        expect(TokenStatus.values, contains(TokenStatus.valid));
        expect(TokenStatus.values, contains(TokenStatus.expired));
        expect(TokenStatus.values, contains(TokenStatus.missing));
      });
    });

    group('Error message patterns', () {
      test('French error messages are user-friendly', () {
        final frenchErrors = [
          'Session expirée. Veuillez vous reconnecter.',
          'Erreur de connexion. Veuillez réessayer.',
          'Erreur de stockage. Veuillez réessayer.',
          'Identifiants incorrects. Veuillez réessayer.',
        ];

        for (final error in frenchErrors) {
          expect(error, contains('Veuillez'));
        }
      });

      test('Storage failure errors are distinguishable', () {
        final storageError = RefreshResult.failure(
          error: 'Erreur de stockage. Veuillez réessayer.',
          failureType: RefreshFailureType.storageFailure,
        );

        final networkError = RefreshResult.failure(
          error: 'Erreur de connexion. Veuillez réessayer.',
          failureType: RefreshFailureType.transientNetwork,
        );

        final authError = RefreshResult.failure(
          error: 'Session expirée. Veuillez vous reconnecter.',
          failureType: RefreshFailureType.invalidToken,
        );

        expect(
          storageError.failureType,
          equals(RefreshFailureType.storageFailure),
        );
        expect(
          networkError.failureType,
          equals(RefreshFailureType.transientNetwork),
        );
        expect(authError.failureType, equals(RefreshFailureType.invalidToken));

        expect(storageError.error, isNot(equals(networkError.error)));
        expect(storageError.error, isNot(equals(authError.error)));
      });
    });
  });
}
