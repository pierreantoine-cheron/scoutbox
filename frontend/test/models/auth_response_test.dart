import 'package:flutter_test/flutter_test.dart';

import 'package:client/models/auth_response.dart';

void main() {
  group('AuthResponse Unit Tests', () {
    group('Basic expiry checks', () {
      test('isAccessTokenExpired returns true when token is past expiry', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: pastTime,
          refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
        );

        expect(response.isAccessTokenExpired, isTrue);
      });

      test(
        'isAccessTokenExpired returns false when token is not yet expired',
        () {
          final futureTime = DateTime.now().add(const Duration(minutes: 5));
          final response = AuthResponse(
            accessToken: 'test_token',
            refreshToken: 'test_refresh',
            accessTokenExpires: futureTime,
            refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
          );

          expect(response.isAccessTokenExpired, isFalse);
        },
      );

      test('isRefreshTokenExpired returns true when token is past expiry', () {
        final pastTime = DateTime.now().subtract(const Duration(days: 1));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpires: pastTime,
        );

        expect(response.isRefreshTokenExpired, isTrue);
      });

      test(
        'isRefreshTokenExpired returns false when token is not yet expired',
        () {
          final futureTime = DateTime.now().add(const Duration(days: 30));
          final response = AuthResponse(
            accessToken: 'test_token',
            refreshToken: 'test_refresh',
            accessTokenExpires: DateTime.now().add(const Duration(minutes: 15)),
            refreshTokenExpires: futureTime,
          );

          expect(response.isRefreshTokenExpired, isFalse);
        },
      );
    });

    group('Clock skew tolerance', () {
      test('isAccessTokenExpiredWithTolerance applies tolerance correctly', () {
        // Token expires 20 seconds from now
        final nearExpiry = DateTime.now().add(const Duration(seconds: 20));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: nearExpiry,
          refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
        );

        // Without tolerance: not expired (20 seconds remaining)
        expect(response.isAccessTokenExpired, isFalse);

        // With 30 second tolerance: expired (20 - 30 = -10 seconds remaining)
        expect(
          response.isAccessTokenExpiredWithTolerance(
            tolerance: const Duration(seconds: 30),
          ),
          isTrue,
        );

        // With 10 second tolerance: not expired (20 - 10 = 10 seconds remaining)
        expect(
          response.isAccessTokenExpiredWithTolerance(
            tolerance: const Duration(seconds: 10),
          ),
          isFalse,
        );
      });

      test(
        'isAccessTokenExpiredWithTolerance uses default 30 second tolerance',
        () {
          // Token expires 25 seconds from now
          final nearExpiry = DateTime.now().add(const Duration(seconds: 25));
          final response = AuthResponse(
            accessToken: 'test_token',
            refreshToken: 'test_refresh',
            accessTokenExpires: nearExpiry,
            refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
          );

          // Default tolerance is 30 seconds: 25 - 30 = -5, so should be expired
          expect(response.isAccessTokenExpiredWithTolerance(), isTrue);
        },
      );

      test('isRefreshTokenExpiredWithTolerance applies tolerance correctly', () {
        // Token expires 20 seconds from now
        final nearExpiry = DateTime.now().add(const Duration(seconds: 20));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpires: nearExpiry,
        );

        // Without tolerance: not expired (20 seconds remaining)
        expect(response.isRefreshTokenExpired, isFalse);

        // With 30 second tolerance: expired (20 - 30 = -10 seconds remaining)
        expect(
          response.isRefreshTokenExpiredWithTolerance(
            tolerance: const Duration(seconds: 30),
          ),
          isTrue,
        );

        // With 10 second tolerance: not expired (20 - 10 = 10 seconds remaining)
        expect(
          response.isRefreshTokenExpiredWithTolerance(
            tolerance: const Duration(seconds: 10),
          ),
          isFalse,
        );
      });

      test(
        'isRefreshTokenExpiredWithTolerance uses default 30 second tolerance',
        () {
          // Token expires 25 seconds from now
          final nearExpiry = DateTime.now().add(const Duration(seconds: 25));
          final response = AuthResponse(
            accessToken: 'test_token',
            refreshToken: 'test_refresh',
            accessTokenExpires: DateTime.now().add(const Duration(minutes: 15)),
            refreshTokenExpires: nearExpiry,
          );

          // Default tolerance is 30 seconds: 25 - 30 = -5, so should be expired
          expect(response.isRefreshTokenExpiredWithTolerance(), isTrue);
        },
      );
    });

    group('Proactive refresh window', () {
      test('isAccessTokenExpiringSoon returns true when within window', () {
        // Token expires 3 minutes from now
        final nearExpiry = DateTime.now().add(const Duration(minutes: 3));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: nearExpiry,
          refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
        );

        // Within 5 minute window: should be expiring soon
        expect(
          response.isAccessTokenExpiringSoon(
            window: const Duration(minutes: 5),
          ),
          isTrue,
        );
      });

      test('isAccessTokenExpiringSoon returns false when outside window', () {
        // Token expires 10 minutes from now
        final farExpiry = DateTime.now().add(const Duration(minutes: 10));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: farExpiry,
          refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
        );

        // Outside 5 minute window: should not be expiring soon
        expect(
          response.isAccessTokenExpiringSoon(
            window: const Duration(minutes: 5),
          ),
          isFalse,
        );
      });

      test('isAccessTokenExpiringSoon uses default 5 minute window', () {
        // Token expires 4 minutes from now (within default 5 minute window)
        final nearExpiry = DateTime.now().add(const Duration(minutes: 4));
        final response = AuthResponse(
          accessToken: 'test_token',
          refreshToken: 'test_refresh',
          accessTokenExpires: nearExpiry,
          refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
        );

        expect(response.isAccessTokenExpiringSoon(), isTrue);
      });
    });

    group('JSON serialization', () {
      test('fromJson parses response correctly', () {
        final now = DateTime.now();
        final json = {
          'accessToken': 'test_access_token',
          'refreshToken': 'test_refresh_token',
          'accessTokenExpires': now.add(const Duration(minutes: 15)).toIso8601String(),
          'refreshTokenExpires': now.add(const Duration(days: 180)).toIso8601String(),
        };

        final response = AuthResponse.fromJson(json);

        expect(response.accessToken, equals('test_access_token'));
        expect(response.refreshToken, equals('test_refresh_token'));
        expect(response.accessTokenExpires, isA<DateTime>());
        expect(response.refreshTokenExpires, isA<DateTime>());
      });

      test('toJson serializes response correctly', () {
        final now = DateTime.now();
        final response = AuthResponse(
          accessToken: 'test_access',
          refreshToken: 'test_refresh',
          accessTokenExpires: now,
          refreshTokenExpires: now.add(const Duration(days: 180)),
        );

        final json = response.toJson();

        expect(json['accessToken'], equals('test_access'));
        expect(json['refreshToken'], equals('test_refresh'));
        expect(json['accessTokenExpires'], equals(now.toIso8601String()));
        expect(
          json['refreshTokenExpires'],
          equals(now.add(const Duration(days: 180)).toIso8601String()),
        );
      });

      test('fromJson throws FormatException on invalid date string', () {
        final json = {
          'accessToken': 'test_access_token',
          'refreshToken': 'test_refresh_token',
          'accessTokenExpires': 'not-a-date',
          'refreshTokenExpires': DateTime.now().add(const Duration(days: 180)).toIso8601String(),
        };

        expect(() => AuthResponse.fromJson(json), throwsFormatException);
      });
    });
  });
}
