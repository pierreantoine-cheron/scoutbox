import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/services/api_client.dart';
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
    ApiClient.reset();
  });

  test('createInvite surfaces a French message as AuthServiceException', () async {
    await SecureStorageService.saveServerUrl('https://example.test');

    ApiClient.initialize('https://example.test');
    ApiClient.instance.httpClientAdapter = _FakeAdapter(
      (options) => _jsonResponse(400, {
        'error': 'Unable to generate an available invite code',
        'code': 'CODE_GENERATION_FAILED',
      }),
    );

    final service = AuthService();

    await expectLater(
      service.createInvite(),
      throwsA(
        isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('générer un code'),
        ),
      ),
    );
  });
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
