import 'package:client/models/tent_history_item.dart';
import 'package:client/providers/tent_history_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_tent_repository.dart';

void main() {
  group('tentHistoryProvider', () {
    test('returns history when repository succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(
            FakeTentRepository()..getTentHistoryHandler = _getHistory,
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(tentHistoryProvider('tent-1').future);

      expect(items.length, 2);
    });

    test('returns error state when repository fails', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(
            FakeTentRepository()
              ..getTentHistoryHandler =
                  ({
                    required String tentId,
                    String? category,
                    int limit = 50,
                  }) async {
                    throw const TentRepositoryException(
                      code: 'INTERNAL_ERROR',
                      message: 'Impossible de charger l\'historique de la tente.',
                    );
                  },
          ),
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
          tentRepositoryProvider.overrideWithValue(
            FakeTentRepository()..getTentHistoryHandler = _getHistory,
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(
        tentHistoryProvider('tent-1', category: 'part_state').future,
      );

      expect(items.isEmpty, true);
    });

    test(
      'invalidateTentHistory refreshes all loaded category variants',
      () async {
        final calls = <String?, int>{};
        final repository = FakeTentRepository()
          ..getTentHistoryHandler =
              ({
                required String tentId,
                String? category,
                int limit = 50,
              }) async {
                calls[category] = (calls[category] ?? 0) + 1;
                return [
                  TentHistoryItem(
                    id: 'evt-${calls[category]}',
                    action: 'tent_created',
                    category: category ?? 'tent_info',
                    occurredAt: DateTime.utc(2026, 5, 19, 10, 0),
                    actorDisplayName: 'Jean',
                    details: [],
                  ),
                ];
              };
        final container = ProviderContainer(
          overrides: [tentRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final allSubscription = container.listen(
          tentHistoryProvider('tent-1'),
          (_, _) {},
        );
        final tentSubscription = container.listen(
          tentHistoryProvider('tent-1', category: 'tent_info'),
          (_, _) {},
        );
        final partStateSubscription = container.listen(
          tentHistoryProvider('tent-1', category: 'part_state'),
          (_, _) {},
        );
        addTearDown(allSubscription.close);
        addTearDown(tentSubscription.close);
        addTearDown(partStateSubscription.close);

        await container.read(tentHistoryProvider('tent-1').future);
        await container.read(
          tentHistoryProvider('tent-1', category: 'tent_info').future,
        );
        await container.read(
          tentHistoryProvider('tent-1', category: 'part_state').future,
        );

        invalidateTentHistory(container, 'tent-1');
        await container.read(tentHistoryProvider('tent-1').future);
        await container.read(
          tentHistoryProvider('tent-1', category: 'tent_info').future,
        );
        await container.read(
          tentHistoryProvider('tent-1', category: 'part_state').future,
        );

        expect(calls[null], 2);
        expect(calls['tent_info'], 2);
        expect(calls['part_state'], 2);
      },
    );
  });
}

Future<List<TentHistoryItem>> _getHistory({
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
      details: [],
    ),
    TentHistoryItem(
      id: 'evt-2',
      action: 'tent_updated',
      category: 'tent_info',
      occurredAt: DateTime.utc(2026, 5, 19, 11, 0),
      actorDisplayName: 'Jean',
      details: [],
    ),
  ];

  if (category != null) {
    return items.where((i) => i.category == category).toList();
  }

  return items;
}
