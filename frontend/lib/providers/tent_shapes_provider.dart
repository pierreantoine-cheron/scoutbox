import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent_shape.dart';
import '../repositories/tent_repository.dart';

part 'tent_shapes_provider.g.dart';

@riverpod
class TentShapesNotifier extends _$TentShapesNotifier {
  @override
  Future<List<TentShape>> build() async {
    final shapes = await ref.read(tentRepositoryProvider).getTentShapes();
    return _sortShapes(shapes);
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final shapes = await ref.read(tentRepositoryProvider).getTentShapes();
      return _sortShapes(shapes);
    });
  }

  List<TentShape> _sortShapes(List<TentShape> shapes) {
    return [...shapes]
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  }
}
