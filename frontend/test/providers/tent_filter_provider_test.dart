import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent.dart';
import 'package:client/providers/tent_filter_provider.dart';
import 'package:client/providers/tent_list_provider.dart';

void main() {
  group('Tent filter providers', () {
    test('default state is unfiltered', () async {
      final container = ProviderContainer(
        overrides: [
          tentListProvider.overrideWith(
            () => _TentListTestNotifier(_sampleTents),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tentListSubscription = container.listen(
        tentListProvider,
        (_, _) {},
      );
      addTearDown(tentListSubscription.close);
      final filterSubscription = container.listen(
        tentListFilterProvider,
        (_, _) {},
      );
      addTearDown(filterSubscription.close);

      await container.read(tentListProvider.future);

      final filtered = container.read(filteredTentListProvider);

      expect(container.read(tentListFilteredModeProvider), isFalse);
      expect(filtered, hasLength(3));
    });

    test(
      'state chip filtering keeps tents matching any selected state',
      () async {
        final container = ProviderContainer(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_sampleTents),
            ),
          ],
        );
        addTearDown(container.dispose);
        final tentListSubscription = container.listen(
          tentListProvider,
          (_, _) {},
        );
        addTearDown(tentListSubscription.close);
        final filterSubscription = container.listen(
          tentListFilterProvider,
          (_, _) {},
        );
        addTearDown(filterSubscription.close);

        await container.read(tentListProvider.future);

        container
            .read(tentListFilterProvider.notifier)
            .toggleState(TentOverallState.good);
        container
            .read(tentListFilterProvider.notifier)
            .toggleState(TentOverallState.needsRepair);

        final filtered = container.read(filteredTentListProvider);

        expect(container.read(tentListFilteredModeProvider), isTrue);
        expect(
          filtered.map((tent) => tent.name),
          containsAll(['Atlas', 'Boreal']),
        );
        expect(filtered.map((tent) => tent.name), isNot(contains('Cerise')));
      },
    );

    test('search applies after 300ms debounce at 2+ characters', () async {
      final container = ProviderContainer(
        overrides: [
          tentListProvider.overrideWith(
            () => _TentListTestNotifier(_sampleTents),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tentListSubscription = container.listen(
        tentListProvider,
        (_, _) {},
      );
      addTearDown(tentListSubscription.close);
      final filterSubscription = container.listen(
        tentListFilterProvider,
        (_, _) {},
      );
      addTearDown(filterSubscription.close);

      await container.read(tentListProvider.future);

      container.read(tentListFilterProvider.notifier).setSearchText('at');

      expect(container.read(filteredTentListProvider), hasLength(3));

      await Future<void>.delayed(const Duration(milliseconds: 320));

      final filtered = container.read(filteredTentListProvider);
      expect(filtered.map((tent) => tent.name), equals(['Atlas']));
    });

    test('search is case-insensitive', () async {
      final container = ProviderContainer(
        overrides: [
          tentListProvider.overrideWith(
            () => _TentListTestNotifier(_sampleTents),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tentListSubscription = container.listen(
        tentListProvider,
        (_, _) {},
      );
      addTearDown(tentListSubscription.close);
      final filterSubscription = container.listen(
        tentListFilterProvider,
        (_, _) {},
      );
      addTearDown(filterSubscription.close);

      await container.read(tentListProvider.future);

      container.read(tentListFilterProvider.notifier).setSearchText('AT');
      await Future<void>.delayed(const Duration(milliseconds: 320));

      final filtered = container.read(filteredTentListProvider);
      expect(filtered.map((tent) => tent.name), equals(['Atlas']));
    });

    test(
      'search below 2 characters does not filter and clear-all resets',
      () async {
        final container = ProviderContainer(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_sampleTents),
            ),
          ],
        );
        addTearDown(container.dispose);
        final tentListSubscription = container.listen(
          tentListProvider,
          (_, _) {},
        );
        addTearDown(tentListSubscription.close);
        final filterSubscription = container.listen(
          tentListFilterProvider,
          (_, _) {},
        );
        addTearDown(filterSubscription.close);

        await container.read(tentListProvider.future);

        container.read(tentListFilterProvider.notifier).setSearchText('at');
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(container.read(filteredTentListProvider), hasLength(1));

        container.read(tentListFilterProvider.notifier).setSearchText('a');

        expect(container.read(filteredTentListProvider), hasLength(3));

        container
            .read(tentListFilterProvider.notifier)
            .toggleState(TentOverallState.unusable);
        expect(container.read(tentListFilteredModeProvider), isTrue);

        container.read(tentListFilterProvider.notifier).clearAll();

        expect(container.read(tentListFilteredModeProvider), isFalse);
        expect(container.read(filteredTentListProvider), hasLength(3));
      },
    );

    test('combined filters apply AND logic between state and search', () async {
      final container = ProviderContainer(
        overrides: [
          tentListProvider.overrideWith(
            () => _TentListTestNotifier(_sampleTents),
          ),
        ],
      );
      addTearDown(container.dispose);
      final tentListSubscription = container.listen(
        tentListProvider,
        (_, _) {},
      );
      addTearDown(tentListSubscription.close);
      final filterSubscription = container.listen(
        tentListFilterProvider,
        (_, _) {},
      );
      addTearDown(filterSubscription.close);

      await container.read(tentListProvider.future);

      container
          .read(tentListFilterProvider.notifier)
          .toggleState(TentOverallState.needsRepair);
      container.read(tentListFilterProvider.notifier).setSearchText('at');

      await Future<void>.delayed(const Duration(milliseconds: 320));

      final filtered = container.read(filteredTentListProvider);
      expect(filtered, isEmpty);
    });
  });
}

class _TentListTestNotifier extends TentListNotifier {
  final List<Tent> tents;

  _TentListTestNotifier(this.tents);

  @override
  Future<List<Tent>> build() async => tents;
}

const _sampleTents = [
  Tent(
    id: 't1',
    name: 'Atlas',
    size: 4,
    tentShapeId: 'shape-1',
    tentShapeName: 'Canadienne',
    overallState: TentOverallState.good,
    comments: null,
  ),
  Tent(
    id: 't2',
    name: 'Boreal',
    size: 2,
    tentShapeId: 'shape-2',
    tentShapeName: 'Tipi',
    overallState: TentOverallState.needsRepair,
    comments: null,
  ),
  Tent(
    id: 't3',
    name: 'Cerise',
    size: 6,
    tentShapeId: 'shape-3',
    tentShapeName: 'Tunnel',
    overallState: TentOverallState.unusable,
    comments: null,
  ),
];
