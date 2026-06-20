import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tag.dart';
import '../repositories/tag_repository.dart';

part 'tags_provider.g.dart';

@riverpod
class TagListRefreshIssueNotifier extends _$TagListRefreshIssueNotifier {
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
class TagsNotifier extends _$TagsNotifier {
  int _latestRefreshRequestId = 0;

  @override
  Future<List<Tag>> build() async {
    return ref.read(tagRepositoryProvider).getTags();
  }

  Future<void> refresh() async {
    final previousState = state;
    final requestId = ++_latestRefreshRequestId;
    ref.read(tagListRefreshIssueProvider.notifier).clear();

    try {
      final tags = await ref.read(tagRepositoryProvider).getTags();
      if (requestId != _latestRefreshRequestId) {
        return;
      }

      state = AsyncValue.data(tags);
    } catch (error, stackTrace) {
      if (requestId != _latestRefreshRequestId) {
        return;
      }

      if (previousState.hasValue) {
        ref.read(tagListRefreshIssueProvider.notifier).setIssue(error);
        state = AsyncValue.data(previousState.requireValue);
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> retry() async {
    ref.read(tagListRefreshIssueProvider.notifier).clear();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(tagRepositoryProvider).getTags();
    });
  }

  Future<Tag> createTag({required String name, String? color}) async {
    final created = await ref.read(tagRepositoryProvider).createTag(name: name, color: color);
    final current = state.hasValue ? state.requireValue : const <Tag>[];
    final next = [created, ...current.where((tag) => tag.id != created.id)]
      ..sort((left, right) => left.name.compareTo(right.name));
    state = AsyncValue.data(next);
    return created;
  }
}
