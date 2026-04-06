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
  Future<List<TentShape>> getTentShapes() async {
    try {
      final response = await ApiClient.instance.get(ApiRoutes.tentShapes);
      final envelope = response.data as Map<String, dynamic>;
      final rawShapes = envelope['data'] as List<dynamic>? ?? [];

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
    }
  }

  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required String overallState,
    String? comments,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiRoutes.tents,
        data: {
          'name': name,
          'size': size,
          'tentShapeId': tentShapeId,
          'overallState': overallState,
          'comments': comments,
        },
      );

      final envelope = response.data as Map<String, dynamic>;
      return Tent.fromJson(envelope['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toRepositoryException(
        e,
        fallbackMessage: 'Impossible de creer la tente. Réessayez.',
      );
    }
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
