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
