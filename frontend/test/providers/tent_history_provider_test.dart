import 'package:client/models/tent_history_item.dart';
import 'package:client/providers/tent_history_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tentHistoryProvider', () {
    test('returns history when repository succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_SuccessHistoryRepository()),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(tentHistoryProvider('tent-1').future);

      expect(items.length, 2);
    });

    test('returns error state when repository fails', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_FailingHistoryRepository()),
        ],
      );
      addTearDown(container.dispose);

      final states = <AsyncValue<List<TentHistoryItem>>>[];
      final subscription = container.listen(tentHistoryProvider('tent-1'), (
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

      AsyncValue<List<TentHistoryItem>>? errorState;
      for (final state in states) {
        if (state.hasError) {
          errorState = state;
        }
      }

      expect(errorState, isNotNull);
      expect(errorState!.error, isA<TentRepositoryException>());
    });

    test('supports category filter', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_SuccessHistoryRepository()),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(
        tentHistoryProvider('tent-1', category: 'part_state').future,
      );

      expect(items.isEmpty, true);
    });
  });
}

class _SuccessHistoryRepository extends TentRepository {
  @override
  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) async {
    final items = [
      TentHistoryItem(
        id: 'evt-1',
        action: 'tent_created',
        category: 'tent_info',
        occurredAt: DateTime.utc(2026, 5, 19, 10, 0),
        actorDisplayName: 'Jean',
        summary: 'Tente créée',
        details: [],
      ),
      TentHistoryItem(
        id: 'evt-2',
        action: 'tent_updated',
        category: 'tent_info',
        occurredAt: DateTime.utc(2026, 5, 19, 11, 0),
        actorDisplayName: 'Jean',
        summary: 'Informations mises à jour',
        details: [],
      ),
    ];

    if (category != null) {
      return items.where((i) => i.category == category).toList();
    }

    return items;
  }
}

class _FailingHistoryRepository extends TentRepository {
  @override
  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) async {
    throw const TentRepositoryException(
      code: 'INTERNAL_ERROR',
      message: 'Impossible de charger l\'historique de la tente.',
    );
  }
}
