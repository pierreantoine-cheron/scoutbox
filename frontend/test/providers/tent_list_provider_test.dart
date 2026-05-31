import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent.dart';
import 'package:client/providers/tent_list_provider.dart';
import 'package:client/repositories/tent_repository.dart';

void main() {
  group('TentListNotifier', () {
    test('loads tents on initialization', () async {
      final repository = _TentListRepositoryStub(
        tents: [
          const Tent(
            id: 't1',
            name: 'Tente A',
            size: 6,
            tentModelId: 'shape-1',
            tentModelName: 'Canadienne',
            overallState: TentOverallState.good,
            comments: null,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final tents = await container.read(tentListProvider.future);

      expect(tents, hasLength(1));
      expect(tents.first.name, equals('Tente A'));
      expect(repository.getTentsCallCount, equals(1));
    });

    test('sets async error when loading fails', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(
            _FailingTentListRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(tentListProvider, (_, _) {});
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(tentListProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<TentRepositoryException>());
    });

    test('refresh retries loading and updates data', () async {
      final repository = _RefreshingTentListRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final initial = await container.read(tentListProvider.future);
      expect(initial.first.name, equals('Tente initiale'));

      await container.read(tentListProvider.notifier).refresh();

      final refreshed = container.read(tentListProvider).requireValue;
      expect(refreshed.first.name, equals('Tente rafraichie'));
      expect(repository.getTentsCallCount, equals(2));
    });

    test('keeps existing list while refresh is in progress', () async {
      final repository = _DelayedRefreshTentListRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(tentListProvider.future);

      final refreshFuture = container.read(tentListProvider.notifier).refresh();

      expect(
        container.read(tentListProvider).requireValue.first.name,
        equals('Tente initiale'),
      );

      repository.completeRefresh();
      await refreshFuture;

      expect(
        container.read(tentListProvider).requireValue.first.name,
        equals('Tente apres refresh'),
      );
    });

    test('keeps existing data and exposes refresh failure', () async {
      final repository = _RefreshFailureTentListRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(tentListProvider.future);

      await container.read(tentListProvider.notifier).refresh();

      expect(
        container.read(tentListProvider).requireValue.first.name,
        equals('Tente initiale'),
      );
      expect(
        container.read(tentListRefreshIssueProvider),
        isA<TentRepositoryException>(),
      );
    });

    test('ignores stale concurrent refresh results', () async {
      final repository = _ConcurrentRefreshTentListRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(tentListProvider.future);

      final firstRefresh = container.read(tentListProvider.notifier).refresh();
      final secondRefresh = container.read(tentListProvider.notifier).refresh();

      repository.completeRefresh(1, const [
        Tent(
          id: 't2',
          name: 'Tente la plus recente',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Canadienne',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ]);
      await secondRefresh;

      repository.completeRefresh(0, const [
        Tent(
          id: 't3',
          name: 'Tente obselete',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Canadienne',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ]);
      await firstRefresh;

      expect(
        container.read(tentListProvider).requireValue.first.name,
        equals('Tente la plus recente'),
      );
      expect(container.read(tentListRefreshIssueProvider), isNull);
    });

    test('hideTent removes tent from current list', () async {
      final repository = _TentListRepositoryStub(
        tents: const [
          Tent(
            id: 't1',
            name: 'Tente A',
            size: 4,
            tentModelId: 'shape-1',
            tentModelName: 'Canadienne',
            overallState: TentOverallState.good,
            comments: null,
          ),
          Tent(
            id: 't2',
            name: 'Tente B',
            size: 6,
            tentModelId: 'shape-2',
            tentModelName: 'Tipi',
            overallState: TentOverallState.needsRepair,
            comments: null,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(tentListProvider.future);
      container.read(tentListProvider.notifier).hideTent('t1');

      final tents = container.read(tentListProvider).requireValue;
      expect(tents, hasLength(1));
      expect(tents.first.id, equals('t2'));
    });
  });
}

class _TentListRepositoryStub extends TentRepository {
  final List<Tent> tents;

  _TentListRepositoryStub({required this.tents});

  int getTentsCallCount = 0;

  @override
  Future<List<Tent>> getTents() async {
    getTentsCallCount++;
    return tents;
  }
}

class _FailingTentListRepository extends TentRepository {
  @override
  Future<List<Tent>> getTents() {
    throw const TentRepositoryException(
      code: 'INTERNAL_ERROR',
      message: 'Erreur serveur. Réessayez.',
    );
  }
}

class _RefreshingTentListRepository extends TentRepository {
  int getTentsCallCount = 0;

  @override
  Future<List<Tent>> getTents() async {
    getTentsCallCount++;

    if (getTentsCallCount == 1) {
      return const [
        Tent(
          id: 't1',
          name: 'Tente initiale',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Tipi',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ];
    }

    return const [
      Tent(
        id: 't1',
        name: 'Tente rafraichie',
        size: 4,
        tentModelId: 'shape-1',
        tentModelName: 'Tipi',
        overallState: TentOverallState.good,
        comments: null,
      ),
    ];
  }
}

class _DelayedRefreshTentListRepository extends TentRepository {
  int getTentsCallCount = 0;
  Completer<List<Tent>>? _refreshCompleter;

  @override
  Future<List<Tent>> getTents() {
    getTentsCallCount++;

    if (getTentsCallCount == 1) {
      return Future.value(const [
        Tent(
          id: 't1',
          name: 'Tente initiale',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Canadienne',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ]);
    }

    _refreshCompleter = Completer<List<Tent>>();
    return _refreshCompleter!.future;
  }

  void completeRefresh() {
    _refreshCompleter?.complete(const [
      Tent(
        id: 't1',
        name: 'Tente apres refresh',
        size: 4,
        tentModelId: 'shape-1',
        tentModelName: 'Canadienne',
        overallState: TentOverallState.good,
        comments: null,
      ),
    ]);
  }
}

class _RefreshFailureTentListRepository extends TentRepository {
  int getTentsCallCount = 0;

  @override
  Future<List<Tent>> getTents() async {
    getTentsCallCount++;

    if (getTentsCallCount == 1) {
      return const [
        Tent(
          id: 't1',
          name: 'Tente initiale',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Canadienne',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ];
    }

    throw const TentRepositoryException(
      code: 'INTERNAL_ERROR',
      message: 'Erreur serveur. Réessayez.',
    );
  }
}

class _ConcurrentRefreshTentListRepository extends TentRepository {
  int getTentsCallCount = 0;
  final List<Completer<List<Tent>>> _refreshCompleters = [];

  @override
  Future<List<Tent>> getTents() {
    getTentsCallCount++;

    if (getTentsCallCount == 1) {
      return Future.value(const [
        Tent(
          id: 't1',
          name: 'Tente initiale',
          size: 4,
          tentModelId: 'shape-1',
          tentModelName: 'Canadienne',
          overallState: TentOverallState.good,
          comments: null,
        ),
      ]);
    }

    final completer = Completer<List<Tent>>();
    _refreshCompleters.add(completer);
    return completer.future;
  }

  void completeRefresh(int index, List<Tent> tents) {
    _refreshCompleters[index].complete(tents);
  }
}
