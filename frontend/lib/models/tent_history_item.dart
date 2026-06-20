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
      case 'tent_unarchived':
        return colorScheme.primary;
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
      case 'tent_unarchived':
        return Icons.unarchive_outlined;
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
        return _buildUpdateText();
      case 'tent_archived':
        return 'Tente archivée';
      case 'tent_unarchived':
        return 'Tente désarchivée';
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

  InlineSpan buildSummarySpan(BuildContext context) {
    final theme = Theme.of(context);
    final normalStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final boldStyle = normalStyle.copyWith(fontWeight: FontWeight.w600);
    final subject = subjectName ?? 'Pièce inconnue';

    switch (action) {
      case 'tent_updated':
        return _buildUpdateSpan(normalStyle, boldStyle);
      case 'part_state_changed':
        final stateDetail =
            details.where((d) => d.valueType == 'state').firstOrNull;
        final oldState = _historyStateLabel(stateDetail?.oldValue);
        final newState = _historyStateLabel(stateDetail?.newValue);
        return TextSpan(children: [
          TextSpan(text: 'État de ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
          TextSpan(text: ' changé de ', style: normalStyle),
          TextSpan(text: oldState, style: boldStyle),
          TextSpan(text: ' à ', style: normalStyle),
          TextSpan(text: newState, style: boldStyle),
        ], style: normalStyle);
      case 'part_comments_changed':
        return TextSpan(children: [
          TextSpan(text: 'Commentaire de ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
          TextSpan(text: ' modifié', style: normalStyle),
        ], style: normalStyle);
      case 'part_added':
        return TextSpan(children: [
          TextSpan(text: 'Pièce ajoutée : ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
        ], style: normalStyle);
      case 'part_deleted':
        return TextSpan(children: [
          TextSpan(text: 'Pièce supprimée : ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
        ], style: normalStyle);
      case 'tag_assigned':
        return TextSpan(children: [
          TextSpan(text: 'Étiquette ajoutée : ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
        ], style: normalStyle);
      case 'tag_removed':
        return TextSpan(children: [
          TextSpan(text: 'Étiquette retirée : ', style: normalStyle),
          TextSpan(text: subject, style: boldStyle),
        ], style: normalStyle);
      default:
        return TextSpan(text: buildSummary(), style: normalStyle);
    }
  }

  String _buildUpdateText() {
    if (details.isEmpty) return 'Informations mises à jour';
    return details.map(_detailToText).join(', ');
  }

  String _detailToText(TentHistoryDetail detail) {
    switch (detail.label) {
      case 'État':
        return 'État général de la tente changé de ${_historyStateLabel(detail.oldValue)} à ${_historyStateLabel(detail.newValue)}';
      case 'Taille':
        return 'Taille de la tente changée de ${detail.oldValue} places à ${detail.newValue} places';
      case 'Nom':
        return 'Nom de la tente changé de ${detail.oldValue} à ${detail.newValue}';
      case 'Modèle':
        return 'Modèle de la tente changé de ${detail.oldValue} à ${detail.newValue}';
      case 'Commentaire':
        return 'Commentaire modifié';
      default:
        return '${detail.label} modifié';
    }
  }

  InlineSpan _buildUpdateSpan(TextStyle normal, TextStyle bold) {
    if (details.isEmpty) {
      return TextSpan(text: 'Informations mises à jour', style: normal);
    }

    final spans = <InlineSpan>[];
    for (var i = 0; i < details.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ', ', style: normal));
      spans.addAll(_detailToSpans(details[i], normal, bold));
    }
    return TextSpan(children: spans, style: normal);
  }

  List<InlineSpan> _detailToSpans(
    TentHistoryDetail detail,
    TextStyle normal,
    TextStyle bold,
  ) {
    switch (detail.label) {
      case 'État':
        return [
          TextSpan(
            text: 'État général de la tente changé de ',
            style: normal,
          ),
          TextSpan(
            text: _historyStateLabel(detail.oldValue),
            style: bold,
          ),
          TextSpan(text: ' à ', style: normal),
          TextSpan(
            text: _historyStateLabel(detail.newValue),
            style: bold,
          ),
        ];
      case 'Taille':
        return [
          TextSpan(
            text: 'Taille de la tente changée de ',
            style: normal,
          ),
          TextSpan(
            text: '${detail.oldValue} places',
            style: bold,
          ),
          TextSpan(text: ' à ', style: normal),
          TextSpan(
            text: '${detail.newValue} places',
            style: bold,
          ),
        ];
      case 'Nom':
        return [
          TextSpan(text: 'Nom de la tente changé de ', style: normal),
          TextSpan(text: detail.oldValue!, style: bold),
          TextSpan(text: ' à ', style: normal),
          TextSpan(text: detail.newValue!, style: bold),
        ];
      case 'Modèle':
        return [
          TextSpan(text: 'Modèle de la tente changé de ', style: normal),
          TextSpan(text: detail.oldValue!, style: bold),
          TextSpan(text: ' à ', style: normal),
          TextSpan(text: detail.newValue!, style: bold),
        ];
      case 'Commentaire':
        return [TextSpan(text: 'Commentaire modifié', style: normal)];
      default:
        return [TextSpan(text: '${detail.label} modifié', style: normal)];
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
