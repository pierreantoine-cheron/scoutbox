import '../utils/date_time_parser.dart';

class TentHistoryItem {
  final String id;
  final String action;
  final String category;
  final DateTime occurredAt;
  final String? actorUserId;
  final String actorDisplayName;
  final String summary;
  final List<TentHistoryDetail> details;
  final String? targetEntityType;
  final String? targetEntityId;

  const TentHistoryItem({
    required this.id,
    required this.action,
    required this.category,
    required this.occurredAt,
    this.actorUserId,
    required this.actorDisplayName,
    required this.summary,
    required this.details,
    this.targetEntityType,
    this.targetEntityId,
  });

  factory TentHistoryItem.fromJson(Map<String, dynamic> json) {
    return TentHistoryItem(
      id: json['id'] as String,
      action: json['action'] as String,
      category: json['category'] as String,
      occurredAt: DateTimeParser.parseRequired(
        json['occurredAt'],
        fieldName: 'occurredAt',
      ),
      actorUserId: json['actorUserId'] as String?,
      actorDisplayName:
          json['actorDisplayName'] as String? ?? 'Utilisateur supprimé',
      summary: json['summary'] as String? ?? '',
      details:
          (json['details'] as List<dynamic>?)
              ?.map(
                (d) => TentHistoryDetail.fromJson(d as Map<String, dynamic>),
              )
              .toList() ??
          [],
      targetEntityType: json['targetEntityType'] as String?,
      targetEntityId: json['targetEntityId'] as String?,
    );
  }
}

class TentHistoryDetail {
  final String label;
  final String? oldValue;
  final String? newValue;
  final String? value;
  final String? valueType;

  const TentHistoryDetail({
    required this.label,
    this.oldValue,
    this.newValue,
    this.value,
    this.valueType,
  });

  factory TentHistoryDetail.fromJson(Map<String, dynamic> json) {
    return TentHistoryDetail(
      label: json['label'] as String? ?? '',
      oldValue: json['oldValue'] as String?,
      newValue: json['newValue'] as String?,
      value: json['value'] as String?,
      valueType: json['valueType'] as String?,
    );
  }
}
