import 'package:client/models/tent.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/providers/tent_edit_provider.dart';
import 'package:client/providers/tent_models_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TentEditNotifier', () {
    test('invalidates tent models after changing a tent model', () async {
      final repository = _ModelChangeTentRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(tentModelsProvider, (_, _) {});
      addTearDown(subscription.close);

      final initialModels = await container.read(tentModelsProvider.future);
      expect(initialModels.single.tentCount, equals(1));

      await container
          .read(tentEditProvider('tent-1').notifier)
          .updateModel(
            tentId: 'tent-1',
            tentModelId: 'model-2',
            name: 'Tente A',
            size: 6,
            overallState: TentOverallState.good,
          );

      final refreshedModels = await container.read(tentModelsProvider.future);
      expect(repository.getTentModelsCallCount, equals(2));
      expect(refreshedModels.single.tentCount, equals(0));
    });
  });
}

class _ModelChangeTentRepository extends TentRepository {
  int getTentModelsCallCount = 0;

  @override
  Future<List<TentModel>> getTentModels() async {
    getTentModelsCallCount++;
    return [
      TentModel(
        id: 'model-1',
        name: 'Canadienne',
        displayOrder: 1,
        isActive: true,
        tentCount: getTentModelsCallCount == 1 ? 1 : 0,
      ),
    ];
  }

  @override
  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
  }) async {
    return Tent(
      id: id,
      name: name,
      size: size,
      tentModelId: tentModelId ?? 'model-1',
      overallState: overallState,
      comments: comments,
    );
  }
}
