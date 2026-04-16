import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';

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
bool tentListFilteredMode(Ref ref) => false;

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
