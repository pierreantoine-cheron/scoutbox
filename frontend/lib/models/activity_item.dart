import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/date_time_parser.dart';
import 'part.dart';
import 'tent.dart';
import 'tent_history_item.dart';

class ActivityPage {
  final List<ActivityItem> items;
  final String? nextCursor;

  const ActivityPage({required this.items, this.nextCursor});

  factory ActivityPage.fromJson(Map<String, dynamic> json) {
    return ActivityPage(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => ActivityItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class ActivityItem {
  final String id;
  final String action;
  final String category;
  final DateTime occurredAt;
  final String actorUserId;
  final String actorDisplayName;
  final String? tentId;
  final String? tentName;
  final String? subjectName;
  final List<TentHistoryDetail> details;

  const ActivityItem({
    required this.id,
    required this.action,
    required this.category,
    required this.occurredAt,
    required this.actorUserId,
    required this.actorDisplayName,
    this.tentId,
    this.tentName,
    this.subjectName,
    required this.details,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] as String,
      action: json['action'] as String,
      category: json['category'] as String,
      occurredAt: DateTimeParser.parseRequired(
        json['occurredAt'],
        fieldName: 'occurredAt',
      ),
      actorUserId: json['actorUserId'] as String,
      actorDisplayName: json['actorDisplayName'] as String,
      tentId: json['tentId'] as String?,
      tentName: json['tentName'] as String?,
      subjectName: json['subjectName'] as String?,
      details:
          (json['details'] as List<dynamic>?)
              ?.map(
                (detail) => TentHistoryDetail.fromJson(detail as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  String? get lead => tentName ?? subjectName;

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
        final stateDetail = details.where((d) => d.valueType == 'state').firstOrNull;
        final oldState = _stateLabel(stateDetail?.oldValue);
        final newState = _stateLabel(stateDetail?.newValue);
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
      case 'tag_created':
        return 'Étiquette créée : $subject';
      case 'tag_renamed':
        return _buildCatalogueRenameText('Étiquette renommée', subject);
      case 'tag_deleted':
        return 'Étiquette supprimée : $subject';
      case 'model_created':
        return 'Modèle créé : $subject';
      case 'model_renamed':
        return _buildCatalogueRenameText('Modèle renommé', subject);
      case 'model_deleted':
        return 'Modèle supprimé : $subject';
      case 'invite_created':
        return 'Invitation créée';
      case 'user_registered_from_invite':
        return 'Compte créé';
      default:
        return 'Activité enregistrée';
    }
  }

  InlineSpan buildRowSpan(BuildContext context) {
    final theme = Theme.of(context);
    final normalStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final boldStyle = normalStyle.copyWith(fontWeight: FontWeight.w600);
    final summary = buildSummarySpan(normalStyle, boldStyle);
    final leadText = lead;

    if (leadText == null || leadText.isEmpty) {
      return summary;
    }

    return TextSpan(
      style: normalStyle,
      children: [
        TextSpan(text: leadText, style: boldStyle),
        TextSpan(text: ' — ', style: normalStyle),
        summary,
      ],
    );
  }

  InlineSpan buildSummarySpan(TextStyle normalStyle, TextStyle boldStyle) {
    final subject = subjectName ?? 'Pièce inconnue';

    switch (action) {
      case 'tent_updated':
        return _buildUpdateSpan(normalStyle, boldStyle);
      case 'part_state_changed':
        final stateDetail = details.where((d) => d.valueType == 'state').firstOrNull;
        final oldState = _stateLabel(stateDetail?.oldValue);
        final newState = _stateLabel(stateDetail?.newValue);
        return TextSpan(
          children: [
            TextSpan(text: 'État de ', style: normalStyle),
            TextSpan(text: subject, style: boldStyle),
            TextSpan(text: ' changé de ', style: normalStyle),
            TextSpan(text: oldState, style: boldStyle),
            TextSpan(text: ' à ', style: normalStyle),
            TextSpan(text: newState, style: boldStyle),
          ],
          style: normalStyle,
        );
      case 'part_comments_changed':
        return TextSpan(
          children: [
            TextSpan(text: 'Commentaire de ', style: normalStyle),
            TextSpan(text: subject, style: boldStyle),
            TextSpan(text: ' modifié', style: normalStyle),
          ],
          style: normalStyle,
        );
      case 'part_added':
        return _subjectSpan('Pièce ajoutée : ', subject, normalStyle, boldStyle);
      case 'part_deleted':
        return _subjectSpan('Pièce supprimée : ', subject, normalStyle, boldStyle);
      case 'tag_assigned':
        return _subjectSpan('Étiquette ajoutée : ', subject, normalStyle, boldStyle);
      case 'tag_removed':
        return _subjectSpan('Étiquette retirée : ', subject, normalStyle, boldStyle);
      case 'tag_created':
        return _subjectSpan('Étiquette créée : ', subject, normalStyle, boldStyle);
      case 'tag_renamed':
        return _catalogueRenameSpan('Étiquette renommée', subject, normalStyle, boldStyle);
      case 'tag_deleted':
        return _subjectSpan('Étiquette supprimée : ', subject, normalStyle, boldStyle);
      case 'model_created':
        return _subjectSpan('Modèle créé : ', subject, normalStyle, boldStyle);
      case 'model_renamed':
        return _catalogueRenameSpan('Modèle renommé', subject, normalStyle, boldStyle);
      case 'model_deleted':
        return _subjectSpan('Modèle supprimé : ', subject, normalStyle, boldStyle);
      default:
        return TextSpan(text: buildSummary(), style: normalStyle);
    }
  }

  TextSpan _subjectSpan(
    String prefix,
    String subject,
    TextStyle normalStyle,
    TextStyle boldStyle,
  ) {
    return TextSpan(
      children: [
        TextSpan(text: prefix, style: normalStyle),
        TextSpan(text: subject, style: boldStyle),
      ],
      style: normalStyle,
    );
  }

  String _buildCatalogueRenameText(String prefix, String subject) {
    final rename = _renameDetail;
    if (rename == null) return '$prefix : $subject';
    return '$prefix de ${rename.oldValue} à ${rename.newValue}';
  }

  TextSpan _catalogueRenameSpan(
    String prefix,
    String subject,
    TextStyle normalStyle,
    TextStyle boldStyle,
  ) {
    final rename = _renameDetail;
    if (rename == null) {
      return _subjectSpan('$prefix : ', subject, normalStyle, boldStyle);
    }

    return TextSpan(
      children: [
        TextSpan(text: '$prefix de ', style: normalStyle),
        TextSpan(text: rename.oldValue!, style: boldStyle),
        TextSpan(text: ' à ', style: normalStyle),
        TextSpan(text: rename.newValue!, style: boldStyle),
      ],
      style: normalStyle,
    );
  }

  TentHistoryDetail? get _renameDetail => details
      .where(
        (detail) =>
            detail.valueType == 'old_new' &&
            (detail.label == 'Étiquette' || detail.label == 'Modèle'),
      )
      .firstOrNull;

  String _buildUpdateText() {
    if (details.isEmpty) return 'Informations mises à jour';
    return details.map(_detailToText).join(', ');
  }

  String _detailToText(TentHistoryDetail detail) {
    switch (detail.label) {
      case 'État':
        return 'État général de la tente changé de ${_stateLabel(detail.oldValue)} à ${_stateLabel(detail.newValue)}';
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
          TextSpan(text: 'État général de la tente changé de ', style: normal),
          TextSpan(text: _stateLabel(detail.oldValue), style: bold),
          TextSpan(text: ' à ', style: normal),
          TextSpan(text: _stateLabel(detail.newValue), style: bold),
        ];
      case 'Taille':
        return [
          TextSpan(text: 'Taille de la tente changée de ', style: normal),
          TextSpan(text: '${detail.oldValue} places', style: bold),
          TextSpan(text: ' à ', style: normal),
          TextSpan(text: '${detail.newValue} places', style: bold),
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

  String localDayLabel({DateTime? now}) {
    final local = occurredAt.toLocal();
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) return "Aujourd'hui";
    if (difference == 1) return 'Hier';

    final formatted = DateFormat('EEEE d MMMM yyyy', 'fr').format(day);
    return formatted.isEmpty
        ? formatted
        : formatted[0].toUpperCase() + formatted.substring(1);
  }

  String localTimeLabel() {
    return DateFormat('HH:mm', 'fr').format(occurredAt.toLocal());
  }

  static String _stateLabel(String? value) {
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
