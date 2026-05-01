import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_colors.dart';

class StateBadgeStyle {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const StateBadgeStyle({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}

StateBadgeStyle tentStateBadgeStyle(
  BuildContext context,
  TentOverallState state,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
  final (icon, background, foreground) = switch (state) {
    TentOverallState.good => (
      Icons.check_circle_outline,
      colorScheme.primaryContainer,
      colorScheme.onPrimaryContainer,
    ),
    TentOverallState.needsRepair => (
      Icons.build_circle_outlined,
      semanticColors.warningContainer,
      semanticColors.onWarningContainer,
    ),
    TentOverallState.unusable => (
      Icons.cancel_outlined,
      colorScheme.errorContainer,
      colorScheme.onErrorContainer,
    ),
  };

  return StateBadgeStyle(
    label: state.toFrenchLabel(),
    icon: icon,
    background: background,
    foreground: foreground,
  );
}

StateBadgeStyle partStateBadgeStyle(BuildContext context, PartState state) {
  final colorScheme = Theme.of(context).colorScheme;
  final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
  final (icon, background, foreground) = switch (state) {
    PartState.good => (
      Icons.check_circle_outline,
      colorScheme.primaryContainer,
      colorScheme.onPrimaryContainer,
    ),
    PartState.needsRepair => (
      Icons.build_circle_outlined,
      semanticColors.warningContainer,
      semanticColors.onWarningContainer,
    ),
    PartState.missing => (
      Icons.remove_circle_outline,
      colorScheme.secondaryContainer,
      colorScheme.onSecondaryContainer,
    ),
    PartState.unusable => (
      Icons.cancel_outlined,
      colorScheme.errorContainer,
      colorScheme.onErrorContainer,
    ),
  };

  return StateBadgeStyle(
    label: state.toFrenchLabel(),
    icon: icon,
    background: background,
    foreground: foreground,
  );
}

class StateBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const StateBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  factory StateBadge.forTent(BuildContext context, TentOverallState state) {
    final style = tentStateBadgeStyle(context, state);

    return StateBadge(
      label: style.label,
      icon: style.icon,
      background: style.background,
      foreground: style.foreground,
    );
  }

  factory StateBadge.forPart(BuildContext context, PartState state) {
    final style = partStateBadgeStyle(context, state);

    return StateBadge(
      label: style.label,
      icon: style.icon,
      background: style.background,
      foreground: style.foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
