import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/services/auth_service.dart';
import 'package:client/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

  setUp(() {
    storage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'write':
          storage[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return storage[args['key'] as String];
        case 'delete':
          storage.remove(args['key'] as String);
          return null;
        case 'deleteAll':
          storage.clear();
          return null;
        case 'containsKey':
          return storage.containsKey(args['key'] as String);
        case 'readAll':
          return storage;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('clearAuthTokensOnly clears the cached auth response', () async {
    final service = AuthService();

    await SecureStorageService.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpires: DateTime.now().add(const Duration(minutes: 15)),
      refreshTokenExpires: DateTime.now().add(const Duration(days: 180)),
    );

    // Populate the in-memory cache via a token validation.
    expect(await service.validateAccessToken(), equals(TokenStatus.valid));
    expect(await service.canRefreshToken(), isTrue);

    // Simulate session expiry: clear tokens but keep server URL/username.
    await service.clearAuthTokensOnly();

    // The cached response must be cleared too, otherwise these report stale data.
    expect(await service.validateAccessToken(), equals(TokenStatus.missing));
    expect(await service.canRefreshToken(), isFalse);
  });
}
