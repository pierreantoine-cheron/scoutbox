import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent_shape.dart';
import '../repositories/tent_repository.dart';

part 'tent_shapes_provider.g.dart';

@riverpod
class TentShapesNotifier extends _$TentShapesNotifier {
  @override
  Future<List<TentShape>> build() async {
    return ref.read(tentRepositoryProvider).getTentShapes();
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(tentRepositoryProvider).getTentShapes(),
    );
  }
}
