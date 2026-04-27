import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';
import 'tent_filter_provider.dart';

part 'tent_list_provider.g.dart';

@riverpod
class TentListRefreshIssueNotifier extends _$TentListRefreshIssueNotifier {
  @override
  Object? build() => null;

  void clear() {
    state = null;
  }

  void setIssue(Object issue) {
    state = issue;
  }
}

@riverpod
bool tentListFilteredMode(Ref ref) {
  return ref.watch(tentListFilterProvider).isFilteredMode;
}

@riverpod
List<Tent> filteredTentList(Ref ref) {
  final tents = ref.watch(tentListProvider).asData?.value;
  final filterState = ref.watch(tentListFilterProvider);

  if (tents == null) {
    return const <Tent>[];
  }

  return tents
      .where((tent) {
        final matchesState =
            filterState.selectedStates.isEmpty ||
            filterState.selectedStates.contains(tent.overallState);

        final search = filterState.effectiveSearchText;
        final matchesSearch =
            search.isEmpty || tent.name.toLowerCase().contains(search);

        final matchesSize =
            filterState.selectedSizes.isEmpty ||
            filterState.selectedSizes.contains(tent.size);

        final matchesShape =
            filterState.selectedShapeIds.isEmpty ||
            filterState.selectedShapeIds.contains(tent.tentShapeId);

        return matchesState && matchesSearch && matchesSize && matchesShape;
      })
      .toList(growable: false);
}

@riverpod
class TentListNotifier extends _$TentListNotifier {
  int _latestRefreshRequestId = 0;

  @override
  Future<List<Tent>> build() async {
    return ref.read(tentRepositoryProvider).getTents();
  }

  Future<void> refresh() async {
    final previousState = state;
    final requestId = ++_latestRefreshRequestId;
    ref.read(tentListRefreshIssueProvider.notifier).clear();

    try {
      final tents = await ref.read(tentRepositoryProvider).getTents();

      if (requestId != _latestRefreshRequestId) {
        return;
      }

      state = AsyncValue.data(tents);
    } catch (error, stackTrace) {
      if (requestId != _latestRefreshRequestId) {
        return;
      }

      if (previousState.hasValue) {
        ref.read(tentListRefreshIssueProvider.notifier).setIssue(error);
        state = AsyncValue.data(previousState.requireValue);
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> retry() async {
    ref.read(tentListRefreshIssueProvider.notifier).clear();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(tentRepositoryProvider).getTents();
    });
  }

  void showTent(Tent tent) {
    final tents = state.hasValue ? state.requireValue : const <Tent>[];
    final nextTents = [
      tent,
      ...tents.where((existingTent) => existingTent.id != tent.id),
    ];
    state = AsyncValue.data(nextTents);
  }
}
