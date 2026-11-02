import 'tent_history_item.dart';

/// French parenthetical describing why an audit event happened, or null.
String? reasonParenthetical(List<TentHistoryDetail> details) {
  final reason = details
      .where((detail) => detail.valueType == 'reason')
      .map((detail) => detail.value)
      .whereType<String>()
      .firstOrNull;
  if (reason == null || reason.isEmpty) return null;

  final label = switch (reason) {
    'tag_deleted' => 'étiquette supprimée',
    'part_kind_deleted' => 'modèle de pièce supprimé',
    _ => reason,
  };
  return ' ($label)';
}
