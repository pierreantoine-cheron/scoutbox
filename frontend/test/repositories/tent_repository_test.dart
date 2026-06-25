import 'dart:convert';

import 'package:client/repositories/tent_repository.dart';
import 'package:client/services/api_client.dart';
import 'package:client/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ApiClient.reset);

  group('TentRepository.setTentTags', () {
    test('returns updated tent with tags on success', () async {
      ApiClient.initialize('https://example.test');
      ApiClient.instance.httpClientAdapter = _FakeAdapter((options) {
        expect(options.method, equals('PUT'));
        expect(options.path, equals('/api/tents/tent-1/tags'));
        expect(
          options.data,
          equals({
            'tagIds': ['tag-1'],
          }),
        );
        return _jsonResponse(200, _tentJson(tags: [_tagJson('tag-1', 'Groupe A')]));
      });

      final tent = await TentRepository().setTentTags(
        tentId: 'tent-1',
        tagIds: ['tag-1'],
      );

      expect(tent.tags, hasLength(1));
      expect(tent.tags.first.name, equals('Groupe A'));
    });

    test('throws localized repository exception on backend error', () async {
      ApiClient.initialize('https://example.test');
      ApiClient.instance.httpClientAdapter = _FakeAdapter((options) {
        return _jsonResponse(400, {
          'error': 'One or more tags not found',
          'code': ErrorCodes.tagNotFound,
        });
      });

      expect(
        () => TentRepository().setTentTags(tentId: 'tent-1', tagIds: ['bad']),
        throwsA(
          isA<TentRepositoryException>()
              .having((error) => error.code, 'code', ErrorCodes.tagNotFound)
              .having(
                (error) => error.message,
                'message',
                contains('étiquette sélectionnée est introuvable'),
              ),
        ),
      );
    });
  });
}

Map<String, dynamic> _tentJson({List<Map<String, dynamic>> tags = const []}) {
  return {
    'id': 'tent-1',
    'name': 'Tente Atlas',
    'size': 6,
    'tentModelId': 'model-1',
    'tentModelName': 'Canadienne',
    'overallState': 'Good',
    'isArchived': false,
    'comments': null,
    'createdAt': '2026-06-01T10:00:00Z',
    'updatedAt': '2026-06-01T10:00:00Z',
    'parts': [],
    'tags': tags,
  };
}

Map<String, dynamic> _tagJson(String id, String name) {
  return {
    'id': id,
    'name': name,
    'color': '#F44336',
    'createdAt': '2026-06-01T10:00:00Z',
    'tentCount': 1,
  };
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
