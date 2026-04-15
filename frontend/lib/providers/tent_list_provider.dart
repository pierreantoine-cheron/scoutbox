import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';

part 'tent_list_provider.g.dart';

@riverpod
class TentListNotifier extends _$TentListNotifier {
  @override
  Future<List<Tent>> build() async {
    return ref.read(tentRepositoryProvider).getTents();
  }

  Future<void> refresh() async {
    final previousState = state;

    try {
      final tents = await ref.read(tentRepositoryProvider).getTents();
      state = AsyncValue.data(tents);
    } catch (error, stackTrace) {
      if (previousState.hasValue) {
        state = AsyncValue.data(previousState.requireValue);
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(tentRepositoryProvider).getTents();
    });
  }
}
