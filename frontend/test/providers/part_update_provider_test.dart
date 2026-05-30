import 'dart:async';

import 'package:client/models/part.dart';
import 'package:client/providers/part_update_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartUpdateNotifier', () {
    test(
      'shows pending state immediately and keeps confirmed state until refresh',
      () async {
        final repository = _ControlledPartRepository();
        final container = ProviderContainer(
          overrides: [tentRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(partUpdateProvider('tent-1').notifier);
        final update = notifier.updatePartState(
          partId: 'part-1',
          previousState: PartState.good,
          newState: PartState.needsRepair,
          previousComments: null,
          newComments: null,
        );

        var state = container.read(partUpdateProvider('tent-1'));
        expect(state.isSaving('part-1'), isTrue);
        expect(
          state.resolveDisplayedState(_part(PartState.good)),
          PartState.needsRepair,
        );

        repository.completeNext(PartState.needsRepair);
        expect(await update, PartUpdateResult.success);

        state = container.read(partUpdateProvider('tent-1'));
        expect(state.isSaving('part-1'), isFalse);
        expect(
          state.resolveDisplayedState(_part(PartState.good)),
          PartState.needsRepair,
        );
        expect(
          state.resolveDisplayedState(_part(PartState.needsRepair)),
          PartState.needsRepair,
        );
        expect(
          state.resolveDisplayedState(_part(PartState.missing)),
          PartState.missing,
        );
      },
    );

    test('rolls back on failure and retries the failed state', () async {
      final repository = _ControlledPartRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(partUpdateProvider('tent-1').notifier);
      final update = notifier.updatePartState(
        partId: 'part-1',
        previousState: PartState.good,
        newState: PartState.unusable,
        previousComments: null,
        newComments: null,
      );

      repository.failNext('Échec réseau.');
      expect(await update, PartUpdateResult.failure);

      var state = container.read(partUpdateProvider('tent-1'));
      expect(state.isSaving('part-1'), isFalse);
      expect(state.errorFor('part-1'), 'Une erreur est survenue. Veuillez réessayer.');
      expect(
        state.resolveDisplayedState(_part(PartState.good)),
        PartState.good,
      );

      final retry = notifier.retry('part-1');
      state = container.read(partUpdateProvider('tent-1'));
      expect(state.isSaving('part-1'), isTrue);
      expect(
        state.resolveDisplayedState(_part(PartState.good)),
        PartState.unusable,
      );

      repository.completeAt(1, PartState.unusable);
      await retry;

      state = container.read(partUpdateProvider('tent-1'));
      expect(state.errorFor('part-1'), isNull);
      expect(
        state.resolveDisplayedState(_part(PartState.good)),
        PartState.unusable,
      );
    });

    test('ignores stale responses for the same part', () async {
      final repository = _ControlledPartRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(partUpdateProvider('tent-1').notifier);
      final first = notifier.updatePartState(
        partId: 'part-1',
        previousState: PartState.good,
        newState: PartState.needsRepair,
        previousComments: null,
        newComments: null,
      );
      final second = notifier.updatePartState(
        partId: 'part-1',
        previousState: PartState.needsRepair,
        newState: PartState.missing,
        previousComments: null,
        newComments: null,
      );

      repository.completeAt(1, PartState.missing);
      expect(await second, PartUpdateResult.success);

      repository.completeAt(0, PartState.needsRepair);
      expect(await first, PartUpdateResult.stale);

      final state = container.read(partUpdateProvider('tent-1'));
      expect(
        state.resolveDisplayedState(_part(PartState.good)),
        PartState.missing,
      );
    });

    test('selecting current state is a no-op', () async {
      final repository = _ControlledPartRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(partUpdateProvider('tent-1').notifier);
      final result = await notifier.updatePartState(
        partId: 'part-1',
        previousState: PartState.good,
        newState: PartState.good,
        previousComments: null,
        newComments: null,
      );

      expect(result, PartUpdateResult.noChange);
      expect(repository.requests, isEmpty);
    });
  });
}

Part _part(PartState state) {
  return Part(
    id: 'part-1',
    partKindId: 'kind-1',
    partKindName: 'Toile extérieure',
    displayOrder: 1,
    state: state,
    comments: null,
  );
}

class _ControlledPartRepository extends TentRepository {
  final requests = <_PartUpdateRequest>[];

  @override
  Future<Part> updatePartState({
    required String id,
    required PartState state,
    required String? comments,
  }) {
    final request = _PartUpdateRequest(id, state, comments);
    requests.add(request);
    return request.completer.future;
  }

  void completeNext(PartState state) => completeAt(0, state);

  void completeAt(int index, PartState state) {
    final request = requests[index];
    request.completer.complete(
      Part(
        id: request.id,
        partKindId: 'kind-1',
        partKindName: 'Toile extérieure',
        displayOrder: 1,
        state: state,
        comments: request.comments,
      ),
    );
  }

  void failNext(String message) {
    requests.first.completer.completeError(
      TentRepositoryException(message: message),
    );
  }
}

class _PartUpdateRequest {
  final String id;
  final PartState state;
  final String? comments;
  final Completer<Part> completer = Completer<Part>();

  _PartUpdateRequest(this.id, this.state, this.comments);
}
