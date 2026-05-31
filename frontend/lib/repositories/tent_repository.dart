import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/error_localizer.dart';
import '../utils/constants.dart';

part 'tent_repository.g.dart';

@riverpod
TentRepository tentRepository(Ref ref) => TentRepository();

class TentRepository {
  Future<List<Tent>> getTents() async {
    return _request(
      fallbackMessage: 'Impossible de charger les tentes. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement des tentes.',
      action: () async {
        final response = await ApiClient.instance.get(ApiRoutes.tents);
        final rawTents = _readEnvelopeList(response.data);

        return rawTents
            .map((tent) => Tent.fromJson(tent as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<List<TentModel>> getTentModels() async {
    return _request(
      fallbackMessage: 'Impossible de charger les modèles de tentes. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement des modèles de tentes.',
      action: () async {
        final response = await ApiClient.instance.get(ApiRoutes.tentModels);
        final rawModels = _readEnvelopeList(response.data);

        final models =
            rawModels
                .map(
                  (model) => TentModel.fromJson(model as Map<String, dynamic>),
                )
                .where((model) => model.isActive)
                .toList()
              ..sort(
                (left, right) =>
                    left.displayOrder.compareTo(right.displayOrder),
              );

        return models;
      },
    );
  }

  Future<Tent> getTent(String id) async {
    return _request(
      fallbackMessage: 'Impossible de charger le détail de la tente.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement du détail.',
      action: () async {
        final response = await ApiClient.instance.get('${ApiRoutes.tents}/$id');
        return Tent.fromJson(_readEnvelopeMap(response.data));
      },
    );
  }

  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
  }) async {
    return _request(
      fallbackMessage: 'Impossible de mettre à jour la tente. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de la mise à jour de la tente.',
      action: () async {
        final response = await ApiClient.instance.put(
          '${ApiRoutes.tents}/$id',
          data: {
            'name': name,
            'size': size,
            'overallState': overallState.toApiValue(),
            'comments': comments,
          },
        );

        return Tent.fromJson(_readEnvelopeMap(response.data));
      },
    );
  }

  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) async {
    return _request(
      fallbackMessage: 'Impossible de créer la tente. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de la création de la tente.',
      action: () async {
        final response = await ApiClient.instance.post(
          ApiRoutes.tents,
          data: {
            'name': name,
            'size': size,
            'tentModelId': tentModelId,
            'overallState': overallState.toApiValue(),
            'comments': comments,
          },
        );

        return Tent.fromJson(_readEnvelopeMap(response.data));
      },
    );
  }

  Future<Tent> archiveTent(String id) async {
    return _request(
      fallbackMessage: 'Impossible d\'archiver la tente. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de l\'archivage de la tente.',
      action: () async {
        final response = await ApiClient.instance.put(
          '${ApiRoutes.tents}/$id/archive',
        );
        return Tent.fromJson(_readEnvelopeMap(response.data));
      },
    );
  }

  Future<List<Part>> addPartsToTent({
    required String tentId,
    required List<String> partKindIds,
  }) async {
    return _request(
      fallbackMessage: 'Impossible d\'ajouter les pièces. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de l\'ajout des pièces.',
      action: () async {
        final response = await ApiClient.instance.post(
          '${ApiRoutes.tentParts}/$tentId/parts',
          data: {'partKindIds': partKindIds},
        );
        final rawParts = _readEnvelopeList(response.data);
        return rawParts
            .map((part) => Part.fromJson(part as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<void> removePart({required String partId}) async {
    return _request(
      fallbackMessage: 'Impossible de supprimer la pièce. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de la suppression de la pièce.',
      action: () async {
        await ApiClient.instance.delete('${ApiRoutes.parts}/$partId');
      },
    );
  }

  Future<List<PartKind>> getPartKinds() async {
    return _request(
      fallbackMessage: 'Impossible de charger les types de pièces.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement des types de pièces.',
      action: () async {
        final response = await ApiClient.instance.get(ApiRoutes.partKinds);
        final rawKinds = _readEnvelopeList(response.data);
        return rawKinds
            .map((kind) => PartKind.fromJson(kind as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) async {
    return _request(
      fallbackMessage: 'Impossible de charger l\'historique de la tente.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors du chargement de l\'historique.',
      action: () async {
        final queryParams = <String, dynamic>{'limit': limit};
        if (category != null) {
          queryParams['category'] = category;
        }
        final response = await ApiClient.instance.get(
          '${ApiRoutes.tents}/$tentId/history',
          queryParameters: queryParams,
        );
        final rawItems = _readEnvelopeList(response.data);
        return rawItems
            .map(
              (item) => TentHistoryItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      },
    );
  }

  Future<Part> updatePartState({
    required String id,
    required PartState state,
    required String? comments,
  }) async {
    return _request(
      fallbackMessage: 'Impossible de mettre à jour l\'élément. Réessayez.',
      invalidResponseMessage:
          'Réponse du serveur invalide lors de la mise à jour de l\'élément.',
      action: () async {
        final response = await ApiClient.instance.put(
          '${ApiRoutes.parts}/$id',
          data: {'state': state.toApiValue(), 'comments': comments},
        );
        return Part.fromJson(_readEnvelopeMap(response.data));
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
      throw TentRepositoryException(message: invalidResponseMessage);
    } on TypeError catch (_) {
      throw TentRepositoryException(message: invalidResponseMessage);
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
        message: ErrorLocalizer.localize(code, fallback: error),
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
