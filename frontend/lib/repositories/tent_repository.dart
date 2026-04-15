import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../models/tent_shape.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

part 'tent_repository.g.dart';

@riverpod
TentRepository tentRepository(Ref ref) => TentRepository();

class TentRepository {
  Future<List<Tent>> getTents() async {
    try {
      final response = await ApiClient.instance.get(ApiRoutes.tents);
      final rawTents = _readEnvelopeList(response.data);

      return rawTents
          .map((tent) => Tent.fromJson(tent as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _toRepositoryException(
        e,
        fallbackMessage: 'Impossible de charger les tentes. Réessayez.',
      );
    } on FormatException catch (_) {
      throw const TentRepositoryException(
        message: 'Réponse du serveur invalide lors du chargement des tentes.',
      );
    } on TypeError catch (_) {
      throw const TentRepositoryException(
        message: 'Réponse du serveur invalide lors du chargement des tentes.',
      );
    }
  }

  Future<List<TentShape>> getTentShapes() async {
    try {
      final response = await ApiClient.instance.get(ApiRoutes.tentShapes);
      final rawShapes = _readEnvelopeList(response.data);

      final shapes =
          rawShapes
              .map((shape) => TentShape.fromJson(shape as Map<String, dynamic>))
              .where((shape) => shape.isActive)
              .toList()
            ..sort(
              (left, right) => left.displayOrder.compareTo(right.displayOrder),
            );

      return shapes;
    } on DioException catch (e) {
      throw _toRepositoryException(
        e,
        fallbackMessage:
            'Impossible de charger les formes de tentes. Réessayez.',
      );
    } on FormatException catch (_) {
      throw const TentRepositoryException(
        message:
            'Réponse du serveur invalide lors du chargement des formes de tentes.',
      );
    } on TypeError catch (_) {
      throw const TentRepositoryException(
        message:
            'Réponse du serveur invalide lors du chargement des formes de tentes.',
      );
    }
  }

  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required TentOverallState overallState,
    String? comments,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.tents,
        data: {
          'name': name,
          'size': size,
          'tentShapeId': tentShapeId,
          'overallState': overallState.toApiValue(),
          'comments': comments,
        },
      );

      return Tent.fromJson(_readEnvelopeMap(response.data));
    } on DioException catch (e) {
      throw _toRepositoryException(
        e,
        fallbackMessage: 'Impossible de créer la tente. Réessayez.',
      );
    } on FormatException catch (_) {
      throw const TentRepositoryException(
        message: 'Réponse du serveur invalide lors de la création de la tente.',
      );
    } on TypeError catch (_) {
      throw const TentRepositoryException(
        message: 'Réponse du serveur invalide lors de la création de la tente.',
      );
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

  TentRepositoryException _toRepositoryException(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      final code = responseData['code'] as String?;
      final error = responseData['error'] as String?;
      return TentRepositoryException(
        code: code,
        message: error ?? fallbackMessage,
      );
    }

    return TentRepositoryException(message: fallbackMessage);
  }
}

class TentRepositoryException implements Exception {
  final String? code;
  final String message;

  const TentRepositoryException({this.code, required this.message});
}
