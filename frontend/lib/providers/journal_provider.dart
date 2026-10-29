import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/activity_item.dart';
import '../repositories/activity_repository.dart';

part 'journal_provider.g.dart';

@riverpod
class JournalNotifier extends _$JournalNotifier {
  int _latestRefreshRequestId = 0;

  @override
  Future<ActivityPage> build() async {
    return _fetch();
  }

  Future<ActivityPage> _fetch() {
    return ref.read(activityRepositoryProvider).getActivity();
  }

  Future<void> refresh() async {
    final previousState = state;
    final requestId = ++_latestRefreshRequestId;

    try {
      final page = await _fetch();
      if (requestId != _latestRefreshRequestId) return;
      state = AsyncValue.data(page);
    } catch (error, stackTrace) {
      if (requestId != _latestRefreshRequestId) return;
      if (previousState.hasValue) {
        state = AsyncValue.data(previousState.requireValue);
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> retry() async {
    _latestRefreshRequestId++;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}
