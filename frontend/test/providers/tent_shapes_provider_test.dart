import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client/models/tent_shape.dart';
import 'package:client/providers/tent_shapes_provider.dart';
import 'package:client/repositories/tent_repository.dart';

void main() {
  group('TentShapesNotifier', () {
    test('loads shapes then retries after failure', () async {
      final fakeRepository = _ToggleTentRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(fakeRepository)],
      );
      addTearDown(container.dispose);

      final first = await container.read(tentShapesProvider.future);
      expect(first.length, equals(2));
      expect(first.first.name, equals('Canadienne'));
      expect(first.map((shape) => shape.displayOrder).toList(), equals([1, 2]));
      expect(fakeRepository.callCount, equals(1));

      fakeRepository.failNext = true;
      await container.read(tentShapesProvider.notifier).retry();
      final stateAfterFailure = container.read(tentShapesProvider);
      expect(stateAfterFailure.hasError, isTrue);
      expect(fakeRepository.callCount, equals(2));

      fakeRepository.failNext = false;
      await container.read(tentShapesProvider.notifier).retry();
      final stateAfterRetry = container.read(tentShapesProvider);
      expect(stateAfterRetry.hasValue, isTrue);
      expect(stateAfterRetry.requireValue.length, equals(2));
      expect(fakeRepository.callCount, equals(3));

      final latest = stateAfterRetry.requireValue;
      expect(latest.first.name, equals('Canadienne'));
      expect(latest.last.name, equals('Tipi'));
    });
  });
}

class _ToggleTentRepository extends TentRepository {
  int callCount = 0;
  bool failNext = false;

  @override
  Future<List<TentShape>> getTentShapes() async {
    callCount++;

    if (failNext) {
      throw Exception('network');
    }

    return const [
      TentShape(id: '2', name: 'Tipi', displayOrder: 2, isActive: true),
      TentShape(id: '1', name: 'Canadienne', displayOrder: 1, isActive: true),
    ];
  }
}
