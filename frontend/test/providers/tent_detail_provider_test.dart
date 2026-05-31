import 'package:client/models/tent.dart';
import 'package:client/providers/tent_detail_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tentDetailProvider', () {
    test('returns tent detail when repository succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
        ],
      );
      addTearDown(container.dispose);

      final tent = await container.read(tentDetailProvider('t-1').future);

      expect(tent.id, equals('t-1'));
      expect(tent.name, equals('Tente détail'));
    });

    test('returns error state when repository fails', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
        ],
      );
      addTearDown(container.dispose);

      final states = <AsyncValue<Tent>>[];
      final subscription = container.listen(tentDetailProvider('t-1'), (
        _,
        next,
      ) {
        states.add(next);
      }, fireImmediately: true);
      addTearDown(subscription.close);

      for (var i = 0; i < 20; i++) {
        if (states.any((state) => state.hasError)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      AsyncValue<Tent>? errorState;
      for (final state in states) {
        if (state.hasError) {
          errorState = state;
        }
      }

      expect(errorState, isNotNull);
      expect(errorState!.error, isA<TentRepositoryException>());
    });
  });
}

class _SuccessTentRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async {
    return const Tent(
      id: 't-1',
      name: 'Tente détail',
      size: 4,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    );
  }
}

class _FailingTentRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async {
    throw const TentRepositoryException(
      code: 'INTERNAL_ERROR',
      message: 'Impossible de charger le détail de la tente.',
    );
  }
}
