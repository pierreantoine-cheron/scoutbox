import 'package:flutter_riverpod/flutter_riverpod.dart' as frp;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../repositories/tent_repository.dart';

part 'tent_history_provider.g.dart';

@riverpod
Future<List<TentHistoryItem>> tentHistory(
  Ref ref,
  String tentId, {
  String? category,
}) async {
  return ref
      .read(tentRepositoryProvider)
      .getTentHistory(tentId: tentId, category: category);
}

void invalidateTentHistory(Object ref, String tentId) {
  if (ref is Ref) {
    ref
      ..invalidate(tentHistoryProvider(tentId))
      ..invalidate(tentHistoryProvider(tentId, category: 'tent_info'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_state'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_management'))
      ..invalidate(tentHistoryProvider(tentId, category: 'archive'));
    return;
  }

  if (ref is frp.WidgetRef) {
    ref
      ..invalidate(tentHistoryProvider(tentId))
      ..invalidate(tentHistoryProvider(tentId, category: 'tent_info'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_state'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_management'))
      ..invalidate(tentHistoryProvider(tentId, category: 'archive'));
    return;
  }

  if (ref is frp.ProviderContainer) {
    ref
      ..invalidate(tentHistoryProvider(tentId))
      ..invalidate(tentHistoryProvider(tentId, category: 'tent_info'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_state'))
      ..invalidate(tentHistoryProvider(tentId, category: 'part_management'))
      ..invalidate(tentHistoryProvider(tentId, category: 'archive'));
    return;
  }

  throw ArgumentError.value(ref, 'ref', 'Unsupported Riverpod ref type');
}
