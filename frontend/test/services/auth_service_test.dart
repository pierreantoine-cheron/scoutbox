import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/constants.dart';

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
        expect(ApiRoutes.refresh, equals('/api/auth/refresh'));
        expect(ApiRoutes.invites, equals('/api/auth/invites'));
      });

      test('StorageKeys are correctly defined', () {
        expect(StorageKeys.accessToken, equals('access_token'));
        expect(StorageKeys.refreshToken, equals('refresh_token'));
        expect(StorageKeys.serverUrl, equals('server_url'));
      });

      test('ApiTimeouts have correct durations', () {
        expect(ApiTimeouts.healthCheck, equals(const Duration(seconds: 5)));
        expect(ApiTimeouts.defaultTimeout, equals(const Duration(seconds: 10)));
        expect(ApiTimeouts.longTimeout, equals(const Duration(seconds: 30)));
      });
    });
  });
}
