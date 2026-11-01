import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final String label;

  /// Plural of [label] for a multi-word label whose head noun is not the last
  /// word ("modèles de pièce"). Single-word labels fall back to appending an
  /// "s".
  final String? pluralLabel;

  const CountBadge({
    super.key,
    required this.count,
    required this.label,
    this.pluralLabel,
  });

  String get _displayLabel {
    if (count <= 1) return label;
    return pluralLabel ?? '${label}s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count $_displayLabel',
      style: AppTheme.monoCaption,
    );
  }
}
