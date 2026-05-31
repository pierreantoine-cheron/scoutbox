import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent_model.dart';
import '../repositories/tent_repository.dart';

part 'tent_models_provider.g.dart';

@riverpod
class TentModelsNotifier extends _$TentModelsNotifier {
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
    return [...models]
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  }
}
