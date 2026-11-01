import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/part_kind.dart';
import '../services/api_client.dart';
import '../services/error_localizer.dart';
import '../utils/constants.dart';

part 'part_kind_repository.g.dart';

@riverpod
PartKindRepository partKindRepository(Ref ref) => PartKindRepository();

class PartKindRepository {
  Future<List<PartKind>> getPartKinds() async {
    return _request(
      fallbackMessage: 'Impossible de charger les modèles de pièce. Réessayez.',
      invalidResponseMessage: 'Réponse du serveur invalide lors du chargement des modèles de pièce.',
      action: () async {
        final response = await ApiClient.instance.get(ApiRoutes.partKinds);
        final rawPartKinds = response.data! as List<dynamic>;

        return rawPartKinds.map((pk) => PartKind.fromJson(pk as Map<String, dynamic>)).toList();
      },
    );
  }

  Future<PartKind> createPartKind({required String name}) async {
    return _request(
      fallbackMessage: 'Impossible de créer le modèle de pièce. Réessayez.',
      invalidResponseMessage: 'Réponse du serveur invalide lors de la création du modèle de pièce.',
      action: () async {
        final response = await ApiClient.instance.post(
          ApiRoutes.partKinds,
          data: {'name': name},
        );

        return PartKind.fromJson(response.data! as Map<String, dynamic>);
      },
    );
  }

  Future<PartKind> renamePartKind(String id, {required String name}) async {
    return _request(
      fallbackMessage: 'Impossible de renommer le modèle de pièce. Réessayez.',
      invalidResponseMessage: 'Réponse du serveur invalide lors du renommage du modèle de pièce.',
      action: () async {
        final response = await ApiClient.instance.put(
          '${ApiRoutes.partKinds}/$id',
          data: {'name': name},
        );

        return PartKind.fromJson(response.data! as Map<String, dynamic>);
      },
    );
  }

  Future<void> deletePartKind(String id) async {
    return _request<void>(
      fallbackMessage: 'Impossible de supprimer le modèle de pièce. Réessayez.',
      invalidResponseMessage: 'Réponse du serveur invalide lors de la suppression du modèle de pièce.',
      action: () async {
        await ApiClient.instance.delete('${ApiRoutes.partKinds}/$id');
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
      throw PartKindRepositoryException(message: invalidResponseMessage);
    } on TypeError catch (_) {
      throw PartKindRepositoryException(message: invalidResponseMessage);
    }
  }

  PartKindRepositoryException _toRepositoryException(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      final rawCode = responseData['code'];
      final code = rawCode is String ? rawCode : null;
      return PartKindRepositoryException(
        code: code,
        message: ErrorLocalizer.localize(code, fallback: fallbackMessage),
      );
    }

    return PartKindRepositoryException(message: fallbackMessage);
  }
}

class PartKindRepositoryException implements Exception {
  final String? code;
  final String message;

  const PartKindRepositoryException({this.code, required this.message});
}
