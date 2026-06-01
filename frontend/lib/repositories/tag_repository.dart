import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tag.dart';
import '../services/api_client.dart';
import '../services/error_localizer.dart';
import '../utils/constants.dart';

part 'tag_repository.g.dart';

@riverpod
TagRepository tagRepository(Ref ref) => TagRepository();

class TagRepository {
  Future<List<Tag>> getTags() async {
    return _request(
      fallbackMessage: 'Impossible de charger les étiquettes. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement des étiquettes.',
      action: () async {
        final response = await ApiClient.instance.get(ApiRoutes.tags);
        final rawTags = _readEnvelopeList(response.data);

        return rawTags
            .map((tag) => Tag.fromJson(tag as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<Tag> createTag({required String name, String? color}) async {
    return _request(
      fallbackMessage: 'Impossible de créer l\'étiquette. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de la création de l\'étiquette.',
      action: () async {
        final response = await ApiClient.instance.post(
          ApiRoutes.tags,
          data: {'name': name, 'color': color},
        );

        return Tag.fromJson(_readEnvelopeMap(response.data));
      },
    );
  }

  Future<T> _request<T>({
    required Future<T> Function() action,
    required String fallbackMessage,
    required String invalidResponseMessage,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw _toRepositoryException(e, fallbackMessage: fallbackMessage);
    } on FormatException catch (_) {
      throw TagRepositoryException(message: invalidResponseMessage);
    } on TypeError catch (_) {
      throw TagRepositoryException(message: invalidResponseMessage);
    }
  }

  List<dynamic> _readEnvelopeList(Object? responseData) {
    final envelope = _asMap(responseData);
    final data = envelope['data'];
    if (data is List<dynamic>) {
      return data;
    }

    throw const FormatException('Response envelope data is not a list');
  }

  Map<String, dynamic> _readEnvelopeMap(Object? responseData) {
    final envelope = _asMap(responseData);
    final data = envelope['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const FormatException('Response envelope data is not an object');
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    throw const FormatException('Response is not a JSON object');
  }

  TagRepositoryException _toRepositoryException(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      final code = responseData['code'] as String?;
      final error = responseData['error'] as String?;
      return TagRepositoryException(
        code: code,
        message: ErrorLocalizer.localize(code, fallback: error),
      );
    }

    return TagRepositoryException(message: fallbackMessage);
  }
}

class TagRepositoryException implements Exception {
  final String? code;
  final String message;

  const TagRepositoryException({this.code, required this.message});
}
