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

  IconData get actionIcon {
    return switch (action) {
      'tent_created' => Icons.add_circle_outline,
      'tent_updated' => Icons.edit_outlined,
      'tent_archived' => Icons.archive_outlined,
      'tent_unarchived' => Icons.unarchive_outlined,
      'part_state_changed' => Icons.swap_horiz,
      'part_comments_changed' => Icons.comment_outlined,
      'part_added' => Icons.add_box_outlined,
      'part_deleted' => Icons.remove_circle_outline,
      'part_kind_created' => Icons.category_outlined,
      'part_kind_renamed' => Icons.edit_outlined,
      'tag_assigned' => Icons.label_outlined,
      'tag_removed' => Icons.label_off_outlined,
      'tag_created' => Icons.label,
      'tag_renamed' => Icons.edit_outlined,
      'tag_color_changed' => Icons.palette_outlined,
      'tag_deleted' => Icons.delete_outline,
      'model_created' => Icons.grid_view_outlined,
      'model_renamed' => Icons.edit_outlined,
      'model_components_changed' => Icons.dashboard_customize_outlined,
      'model_deleted' => Icons.delete_outline,
      'invite_created' => Icons.mail_outline,
      'user_registered_from_invite' => Icons.person_add_alt_1_outlined,
      _ => Icons.info_outline,
    };
  }

  Color actionDotColor(ColorScheme colorScheme) {
    return switch (action) {
      'tent_created' || 'tent_updated' || 'tent_unarchived' => colorScheme.primary,
      'tent_archived' || 'part_deleted' || 'tag_deleted' || 'model_deleted' =>
        colorScheme.error,
      'part_state_changed' || 'part_added' => colorScheme.tertiary,
      'model_components_changed' => colorScheme.tertiary,
      'part_comments_changed' => colorScheme.primary,
      'part_kind_created' || 'part_kind_renamed' => colorScheme.primary,
      'tag_assigned' ||
      'tag_removed' ||
      'tag_created' ||
      'tag_renamed' ||
      'tag_color_changed' => colorScheme.secondary,
      'model_created' || 'model_renamed' => colorScheme.primary,
      'invite_created' || 'user_registered_from_invite' => colorScheme.tertiary,
      _ => colorScheme.outline,
    };
  }

  String buildSummary() {
    final subject = subjectName ?? _unknownSubject;

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
      case 'part_kind_created':
        return 'Modèle de pièce créé : $subject';
      case 'part_kind_renamed':
        return _buildPartKindRenameText(subject);
      case 'tag_assigned':
        return 'Étiquette ajoutée : $subject';
      case 'tag_removed':
        return 'Étiquette retirée : $subject${_reasonParenthetical ?? ''}';
      case 'tag_created':
        return 'Étiquette créée : $subject';
      case 'tag_renamed':
        return _buildCatalogueRenameText('Étiquette renommée', subject);
      case 'tag_color_changed':
        return 'Couleur de l\'étiquette modifiée : $subject';
      case 'tag_deleted':
        return 'Étiquette supprimée : $subject';
      case 'model_created':
        return 'Modèle de tente créé : $subject';
      case 'model_renamed':
        return _buildCatalogueRenameText('Modèle de tente renommé', subject);
      case 'model_components_changed':
        return _buildComponentChangeText();
      case 'model_deleted':
        return 'Modèle de tente supprimé : $subject';
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
        TextSpan(text: ' : ', style: normalStyle),
        summary,
      ],
    );
  }

  InlineSpan buildSummarySpan(TextStyle normalStyle, TextStyle boldStyle) {
    final subject = subjectName ?? _unknownSubject;

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
      case 'part_kind_created':
        return _subjectSpan('Modèle de pièce créé : ', subject, normalStyle, boldStyle);
      case 'part_kind_renamed':
        return _partKindRenameSpan(subject, normalStyle, boldStyle);
      case 'tag_assigned':
        return _subjectSpan('Étiquette ajoutée : ', subject, normalStyle, boldStyle);
      case 'tag_removed':
        return _subjectSpan(
          'Étiquette retirée : ',
          subject,
          normalStyle,
          boldStyle,
          suffix: _reasonParenthetical,
        );
      case 'tag_created':
        return _subjectSpan('Étiquette créée : ', subject, normalStyle, boldStyle);
      case 'tag_renamed':
        return _catalogueRenameSpan('Étiquette renommée', subject, normalStyle, boldStyle);
      case 'tag_color_changed':
        return _subjectSpan('Couleur de l\'étiquette modifiée : ', subject, normalStyle, boldStyle);
      case 'tag_deleted':
        return _subjectSpan('Étiquette supprimée : ', subject, normalStyle, boldStyle);
      case 'model_created':
        return _subjectSpan('Modèle de tente créé : ', subject, normalStyle, boldStyle);
      case 'model_renamed':
        return _catalogueRenameSpan('Modèle de tente renommé', subject, normalStyle, boldStyle);
      case 'model_components_changed':
        return _componentChangeSpan(normalStyle, boldStyle);
      case 'model_deleted':
        return _subjectSpan('Modèle de tente supprimé : ', subject, normalStyle, boldStyle);
      default:
        return TextSpan(text: buildSummary(), style: normalStyle);
    }
  }

  TextSpan _subjectSpan(
    String prefix,
    String subject,
    TextStyle normalStyle,
    TextStyle boldStyle, {
    String? suffix,
  }) {
    return TextSpan(
      children: [
        TextSpan(text: prefix, style: normalStyle),
        TextSpan(text: subject, style: boldStyle),
        if (suffix != null) TextSpan(text: suffix, style: normalStyle),
      ],
      style: normalStyle,
    );
  }

  String _buildPartKindRenameText(String subject) {
    final rename = _renameDetail;
    if (rename == null) return 'Modèle de pièce renommé : $subject';
    return 'Modèle de pièce renommé : ${rename.oldValue} → ${rename.newValue}';
  }

  TextSpan _partKindRenameSpan(
    String subject,
    TextStyle normalStyle,
    TextStyle boldStyle,
  ) {
    final rename = _renameDetail;
    if (rename == null) {
      return _subjectSpan(
        'Modèle de pièce renommé : ',
        subject,
        normalStyle,
        boldStyle,
      );
    }

    return TextSpan(
      children: [
        TextSpan(text: 'Modèle de pièce renommé : ', style: normalStyle),
        TextSpan(text: rename.oldValue!, style: boldStyle),
        TextSpan(text: ' → ', style: normalStyle),
        TextSpan(text: rename.newValue!, style: boldStyle),
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

  String? get _reasonParenthetical {
    final reason = details
        .where((detail) => detail.valueType == 'reason')
        .map((detail) => detail.value)
        .whereType<String>()
        .firstOrNull;
    if (reason == null || reason.isEmpty) return null;

    final label = switch (reason) {
      'tag_deleted' => 'étiquette supprimée',
      _ => reason,
    };
    return ' ($label)';
  }

  TentHistoryDetail? get _renameDetail => details
      .where(
        (detail) =>
            detail.valueType == 'old_new' &&
            (detail.label == 'Étiquette' ||
                detail.label == 'Modèle de tente' ||
                detail.label == 'Modèle de pièce'),
      )
      .firstOrNull;

  TentHistoryDetail? get _componentChangeDetail =>
      details.where((detail) => detail.valueType == 'components').firstOrNull;

  String _buildComponentChangeText() {
    final change = _componentChangeDetail;
    if (change == null) return 'Modèles de pièce du modèle de tente modifiés';
    return 'Modèles de pièce changés de ${_componentSetLabel(change.oldValue)} à ${_componentSetLabel(change.newValue)}';
  }

  TextSpan _componentChangeSpan(TextStyle normalStyle, TextStyle boldStyle) {
    final change = _componentChangeDetail;
    if (change == null) {
      return TextSpan(
        text: 'Modèles de pièce du modèle de tente modifiés',
        style: normalStyle,
      );
    }

    return TextSpan(
      children: [
        TextSpan(text: 'Modèles de pièce changés de ', style: normalStyle),
        TextSpan(text: _componentSetLabel(change.oldValue), style: boldStyle),
        TextSpan(text: ' à ', style: normalStyle),
        TextSpan(text: _componentSetLabel(change.newValue), style: boldStyle),
      ],
      style: normalStyle,
    );
  }

  static String _componentSetLabel(String? value) {
    if (value == null || value.trim().isEmpty) return 'aucun';
    return value;
  }

  String get _unknownSubject {
    return switch (action) {
      'part_state_changed' ||
      'part_comments_changed' ||
      'part_added' ||
      'part_deleted' => 'Pièce inconnue',
      'part_kind_created' || 'part_kind_renamed' => 'Modèle de pièce inconnu',
      'model_created' ||
      'model_renamed' ||
      'model_components_changed' ||
      'model_deleted' => 'Modèle de tente inconnu',
      'tag_assigned' ||
      'tag_removed' ||
      'tag_created' ||
      'tag_renamed' ||
      'tag_color_changed' ||
      'tag_deleted' => 'Étiquette inconnue',
      'tent_created' || 'tent_updated' || 'tent_archived' || 'tent_unarchived' => 'Tente inconnue',
      _ => 'Inconnu',
    };
  }

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
      case 'Modèle de tente':
        return 'Modèle de tente changé de ${detail.oldValue} à ${detail.newValue}';
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
      case 'Modèle de tente':
        return [
          TextSpan(text: 'Modèle de tente changé de ', style: normal),
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
