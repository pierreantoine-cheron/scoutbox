import 'package:flutter/material.dart';

import '../utils/date_time_parser.dart';
import 'part.dart';
import 'tent.dart';

class TentHistoryItem {
  final String id;
  final String action;
  final String category;
  final DateTime occurredAt;
  final String? actorUserId;
  final String actorDisplayName;
  final String? subjectName;
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
    this.subjectName,
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
      subjectName: json['subjectName'] as String?,
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

  static Color actionDotColor(String action, ColorScheme colorScheme) {
    switch (action) {
      case 'tent_created':
      case 'tent_updated':
      case 'part_comments_changed':
        return colorScheme.primary;
      case 'tent_archived':
      case 'part_deleted':
        return colorScheme.error;
      case 'part_state_changed':
      case 'part_added':
        return colorScheme.tertiary;
      case 'tag_assigned':
      case 'tag_removed':
        return colorScheme.secondary;
      default:
        return colorScheme.outline;
    }
  }

  static IconData actionIcon(String action) {
    switch (action) {
      case 'tent_created':
        return Icons.add_circle_outline;
      case 'tent_updated':
        return Icons.edit_outlined;
      case 'tent_archived':
        return Icons.archive_outlined;
      case 'part_state_changed':
        return Icons.swap_horiz;
      case 'part_comments_changed':
        return Icons.comment_outlined;
      case 'part_added':
        return Icons.add_box_outlined;
      case 'part_deleted':
        return Icons.remove_circle_outline;
      case 'tag_assigned':
        return Icons.label_outlined;
      case 'tag_removed':
        return Icons.label_off_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String buildSummary() {
    final subject = subjectName ?? 'Pièce inconnue';

    switch (action) {
      case 'tent_created':
        return 'Tente créée';
      case 'tent_updated':
        return 'Informations mises à jour';
      case 'tent_archived':
        return 'Tente archivée';
      case 'part_state_changed':
        final stateDetail =
            details.where((d) => d.valueType == 'state').firstOrNull;
        final oldState = _historyStateLabel(stateDetail?.oldValue);
        final newState = _historyStateLabel(stateDetail?.newValue);
        return 'État de $subject changé de $oldState à $newState';
      case 'part_comments_changed':
        return 'Commentaire de $subject modifié';
      case 'part_added':
        return 'Pièce ajoutée : $subject';
      case 'part_deleted':
        return 'Pièce supprimée : $subject';
      case 'tag_assigned':
        return 'Étiquette ajoutée : $subject';
      case 'tag_removed':
        return 'Étiquette retirée : $subject';
      default:
        return 'Action $action';
    }
  }

  static String _historyStateLabel(String? value) {
    if (value == null || value.isEmpty) return '?';

    final partState = PartState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;
    if (partState != null) return partState.toFrenchLabel();

    final tentState = TentOverallState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;
    if (tentState != null) return tentState.toFrenchLabel();

    return value;
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
