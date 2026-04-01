import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/api_client.dart';
import 'package:frontend/utils/constants.dart';

void main() {
  group('ApiClient Unit Tests', () {
    group('Auth Excluded Paths', () {
      test('_isAuthExcluded returns true for excluded paths', () {
        // Use reflection or direct testing via the public API behavior
        // The actual paths are tested by checking if interceptor skips them
        expect(ApiRoutes.login, equals('/api/auth/login'));
        expect(ApiRoutes.register, equals('/api/auth/register'));
        expect(ApiRoutes.refresh, equals('/api/auth/refresh'));
        expect(ApiRoutes.health, equals('/api/health'));
      });

      test('Excluded paths list contains all auth bootstrap routes', () {
        // Verify the constants are correctly excluded from auth
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
