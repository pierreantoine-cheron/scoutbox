import 'package:flutter_test/flutter_test.dart';

import 'package:client/services/api_client.dart';
import 'package:client/services/auth_service.dart' show RefreshResult, RefreshFailureType;
import 'package:client/utils/constants.dart';

void main() {
  group('ApiClient Unit Tests', () {
    group('Auth Excluded Paths', () {
      test('_isAuthExcluded returns true for excluded paths', () {
        expect(ApiRoutes.login, equals('/api/auth/login'));
        expect(ApiRoutes.register, equals('/api/auth/register'));
        expect(ApiRoutes.refresh, equals('/api/auth/refresh'));
        expect(ApiRoutes.health, equals('/api/health'));
      });

      test('Excluded paths list contains all auth bootstrap routes', () {
        final excludedPaths = [
          ApiRoutes.login,
          ApiRoutes.register,
          ApiRoutes.refresh,
          ApiRoutes.health,
        ];

        expect(excludedPaths.length, equals(4));
        expect(excludedPaths, contains('/api/auth/login'));
        expect(excludedPaths, contains('/api/auth/register'));
        expect(excludedPaths, contains('/api/auth/refresh'));
        expect(excludedPaths, contains('/api/health'));
      });
    });

    group('Path exclusion security', () {
      test('exact excluded paths are correctly identified', () {
        final excludedPaths = [
          ApiRoutes.login,
          ApiRoutes.register,
          ApiRoutes.refresh,
          ApiRoutes.health,
        ];

        for (final path in excludedPaths) {
          expect(
            excludedPaths.any((excluded) {
              if (!path.startsWith(excluded)) return false;
              if (path.length == excluded.length) return true;
              return path[excluded.length] == '/';
            }),
            isTrue,
            reason: '$path should be excluded',
          );
        }
      });

      test('paths with trailing slash are correctly excluded', () {
        final pathsWithSlash = [
          '/api/auth/login/',
          '/api/auth/register/',
          '/api/auth/refresh/',
          '/api/health/',
        ];

        final excludedPaths = [
          ApiRoutes.login,
          ApiRoutes.register,
          ApiRoutes.refresh,
          ApiRoutes.health,
        ];

        for (final path in pathsWithSlash) {
          expect(
            excludedPaths.any((excluded) {
              if (!path.startsWith(excluded)) return false;
              if (path.length == excluded.length) return true;
              return path[excluded.length] == '/';
            }),
            isTrue,
            reason: '$path should be excluded',
          );
        }
      });

      test('malicious path suffixes are NOT excluded', () {
        final maliciousPaths = [
          '/api/auth/loginMalicious',
          '/api/auth/registerEvil',
          '/api/auth/refreshToken',
          '/api/healthCheck',
          '/api/users/refresh-token',
        ];

        final excludedPaths = [
          ApiRoutes.login,
          ApiRoutes.register,
          ApiRoutes.refresh,
          ApiRoutes.health,
        ];

        for (final path in maliciousPaths) {
          expect(
            excludedPaths.any((excluded) {
              if (!path.startsWith(excluded)) return false;
              if (path.length == excluded.length) return true;
              return path[excluded.length] == '/';
            }),
            isFalse,
            reason: '$path should NOT be excluded (security bypass attempt)',
          );
        }
      });

      test('paths containing excluded as substring are NOT excluded', () {
        final substringPaths = [
          '/api/users/refresh-token',
          '/api/admin/login',
          '/api/v2/auth/login',
        ];

        final excludedPaths = [
          ApiRoutes.login,
          ApiRoutes.register,
          ApiRoutes.refresh,
          ApiRoutes.health,
        ];

        for (final path in substringPaths) {
          expect(
            excludedPaths.any((excluded) {
              if (!path.startsWith(excluded)) return false;
              if (path.length == excluded.length) return true;
              return path[excluded.length] == '/';
            }),
            isFalse,
            reason: '$path should NOT be excluded (not starting with excluded path)',
          );
        }
      });
    });

    group('ApiClient singleton behavior', () {
      test(
        'ApiClient throws StateError when accessed before initialization',
        () {
          ApiClient.reset();

          expect(
            () => ApiClient.instance,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('ApiClient not initialized'),
              ),
            ),
          );
        },
      );

      test('ApiClient.initialize sets baseUrl correctly', () {
        const testUrl = 'https://test.scoutbox.app';
        ApiClient.initialize(testUrl);

        expect(ApiClient.baseUrl, equals(testUrl));
      });

      test('ApiClient.updateBaseUrl updates the base URL', () {
        const initialUrl = 'https://initial.scoutbox.app';
        const newUrl = 'https://new.scoutbox.app';

        ApiClient.initialize(initialUrl);
        expect(ApiClient.baseUrl, equals(initialUrl));

        ApiClient.updateBaseUrl(newUrl);
        expect(ApiClient.baseUrl, equals(newUrl));
      });

      test('ApiClient.reset clears the instance', () {
        ApiClient.initialize('https://test.scoutbox.app');
        expect(ApiClient.baseUrl, isNotNull);

        ApiClient.reset();
        expect(ApiClient.baseUrl, isNull);
      });

      test('ApiClient.initializeWithAuth guards against duplicate init', () {
        const testUrl = 'https://test.scoutbox.app';

        ApiClient.initializeWithAuth(
          testUrl,
          getToken: () async => 'test_token',
          needsRefresh: () async => false,
          performRefresh: () async => RefreshResult.failure(
            error: 'test',
            failureType: RefreshFailureType.transientNetwork,
          ),
          onAuthFailure: (failureType) {},
        );

        expect(ApiClient.baseUrl, equals(testUrl));

        // Second call with same URL should be a no-op
        ApiClient.initializeWithAuth(
          testUrl,
          getToken: () async => 'test_token_2',
          needsRefresh: () async => false,
          performRefresh: () async => RefreshResult.failure(
            error: 'test',
            failureType: RefreshFailureType.transientNetwork,
          ),
          onAuthFailure: (failureType) {},
        );

        // baseUrl should still be the same
        expect(ApiClient.baseUrl, equals(testUrl));
      });

      test('initializeWithAuth upgrades non-auth client on same URL', () {
        const testUrl = 'https://test.scoutbox.app';

        ApiClient.initialize(testUrl);
        final interceptorsBefore = ApiClient.instance.interceptors.length;

        ApiClient.initializeWithAuth(
          testUrl,
          getToken: () async => 'test_token',
          needsRefresh: () async => false,
          performRefresh: () async => RefreshResult.failure(
            error: 'test',
            failureType: RefreshFailureType.transientNetwork,
          ),
          onAuthFailure: (failureType) {},
        );

        expect(ApiClient.baseUrl, equals(testUrl));
        expect(
          ApiClient.instance.interceptors.length,
          greaterThan(interceptorsBefore),
        );
      });
    });

    group('Health check client', () {
      test('createHealthCheckClient returns a Dio instance', () {
        const testUrl = 'https://test.scoutbox.app';
        final client = ApiClient.createHealthCheckClient(testUrl);

        expect(client, isNotNull);
        expect(client.options.baseUrl, equals(testUrl));
        expect(client.options.connectTimeout, equals(ApiTimeouts.healthCheck));
        expect(client.options.receiveTimeout, equals(ApiTimeouts.healthCheck));
      });
    });
  });
}
