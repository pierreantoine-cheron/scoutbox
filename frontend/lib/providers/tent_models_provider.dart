import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent_model.dart';
import '../repositories/tent_repository.dart';

part 'tent_models_provider.g.dart';

@riverpod
class TentModelsNotifier extends _$TentModelsNotifier {
  int _latestRefreshRequestId = 0;

  @override
  Future<List<TentModel>> build() async {
    final models = await ref.read(tentRepositoryProvider).getTentModels();
    return _sortModels(models);
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final models = await ref.read(tentRepositoryProvider).getTentModels();
      return _sortModels(models);
    });
  }

  List<TentModel> _sortModels(List<TentModel> models) {
    return [...models]..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  }

  Future<void> refresh() async {
    final requestId = ++_latestRefreshRequestId;
    try {
      final models = await ref.read(tentRepositoryProvider).getTentModels();
      if (requestId == _latestRefreshRequestId) {
        state = AsyncValue.data(models);
      }
    } catch (error) {
      if (requestId == _latestRefreshRequestId) {
        rethrow;
      }
    }
  }

  Future<TentModel> createModel({
    required String name,
    required List<String> componentIds,
  }) async {
    final created = await ref
        .read(tentRepositoryProvider)
        .createTentModel(name: name, componentIds: componentIds);
    if (state.hasValue) {
      final next = [...state.requireValue, created]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      state = AsyncValue.data(next);
    }
    return created;
  }

  Future<TentModel> updateModel(
    String id, {
    String? name,
    List<String>? componentIds,
  }) async {
    final updated = await ref
        .read(tentRepositoryProvider)
        .updateTentModel(id, name: name, componentIds: componentIds);
    if (state.hasValue) {
      final next = state.requireValue
          .map((m) => m.id == id ? updated : m)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      state = AsyncValue.data(next);
    }
    return updated;
  }

  Future<void> deleteModel(String id) async {
    await ref.read(tentRepositoryProvider).deleteTentModel(id);
    if (!state.hasValue) return;
    final next = state.requireValue.where((m) => m.id != id).toList();
    state = AsyncValue.data(next);
  }
}