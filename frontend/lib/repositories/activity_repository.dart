import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/activity_item.dart';
import '../services/api_client.dart';
import '../services/error_localizer.dart';
import '../utils/constants.dart';

part 'activity_repository.g.dart';

@riverpod
ActivityRepository activityRepository(Ref ref) => ActivityRepository();

class ActivityRepository {
  Future<ActivityPage> getActivity({
    String category = 'all',
    String window = '30',
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'category': category,
        'window': window,
        'limit': limit,
      };
      if (cursor != null) {
        queryParameters['cursor'] = cursor;
      }

      final response = await ApiClient.instance.get(
        ApiRoutes.activity,
        queryParameters: queryParameters,
      );
      return ActivityPage.fromJson(response.data! as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toRepositoryException(
        e,
        fallbackMessage: 'Impossible de charger le journal. Réessayez.',
      );
    } on FormatException catch (_) {
      throw const ActivityRepositoryException(
        message: 'Réponse du serveur invalide lors du chargement du journal.',
      );
    } on TypeError catch (_) {
      throw const ActivityRepositoryException(
        message: 'Réponse du serveur invalide lors du chargement du journal.',
      );
    }
  }

  ActivityRepositoryException _toRepositoryException(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      final code = responseData['code'] as String?;
      return ActivityRepositoryException(
        code: code,
        message: ErrorLocalizer.localize(code, fallback: fallbackMessage),
      );
    }

    return ActivityRepositoryException(message: fallbackMessage);
  }
}

class ActivityRepositoryException implements Exception {
  final String? code;
  final String message;

  const ActivityRepositoryException({this.code, required this.message});
}
