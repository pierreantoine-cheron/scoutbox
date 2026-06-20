import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/part_kind.dart';
import '../repositories/part_kind_repository.dart';

part 'part_kinds_provider.g.dart';

@riverpod
class PartKindsRefreshIssueNotifier extends _$PartKindsRefreshIssueNotifier {
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
class PartKindsNotifier extends _$PartKindsNotifier {
  int _latestRefreshRequestId = 0;

  @override
  Future<List<PartKind>> build() async {
    return ref.read(partKindRepositoryProvider).getPartKinds();
  }

  Future<void> refresh() async {
    final previousState = state;
    final requestId = ++_latestRefreshRequestId;
    ref.read(partKindsRefreshIssueProvider.notifier).clear();

    try {
      final partKinds = await ref.read(partKindRepositoryProvider).getPartKinds();
      if (requestId != _latestRefreshRequestId) {
        return;
      }

      state = AsyncValue.data(partKinds);
    } catch (error, stackTrace) {
      if (requestId != _latestRefreshRequestId) {
        return;
      }

      if (previousState.hasValue) {
        ref.read(partKindsRefreshIssueProvider.notifier).setIssue(error);
        state = AsyncValue.data(previousState.requireValue);
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> retry() async {
    ref.read(partKindsRefreshIssueProvider.notifier).clear();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(partKindRepositoryProvider).getPartKinds();
    });
  }

  Future<PartKind> createPartKind({required String name}) async {
    final created = await ref.read(partKindRepositoryProvider).createPartKind(name: name);
    final current = state.hasValue ? state.requireValue : const <PartKind>[];
    final next = [...current, created];
    state = AsyncValue.data(next);
    return created;
  }

  Future<PartKind> renamePartKind(String id, {required String name}) async {
    final updated = await ref.read(partKindRepositoryProvider).renamePartKind(id, name: name);
    if (!state.hasValue) return updated;
    final next = state.requireValue.map((pk) => pk.id == id ? updated : pk).toList();
    state = AsyncValue.data(next);
    return updated;
  }

  Future<void> deletePartKind(String id) async {
    await ref.read(partKindRepositoryProvider).deletePartKind(id);
    if (!state.hasValue) return;
    final next = state.requireValue.where((pk) => pk.id != id).toList();
    state = AsyncValue.data(next);
  }
}
