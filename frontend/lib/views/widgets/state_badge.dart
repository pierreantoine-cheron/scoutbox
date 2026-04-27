import 'package:flutter/material.dart';

import '../../models/part.dart';
import '../../models/tent.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (state) {
      TentOverallState.good => (
        Icons.check_circle_outline,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      TentOverallState.needsRepair => (
        Icons.build_circle_outlined,
        Colors.orange.shade100,
        Colors.orange.shade900,
      ),
      TentOverallState.unusable => (
        Icons.cancel_outlined,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return StateBadge(
      label: state.toFrenchLabel(),
      icon: icon,
      background: background,
      foreground: foreground,
    );
  }

  factory StateBadge.forPart(BuildContext context, PartState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (state) {
      PartState.good => (
        Icons.check_circle_outline,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      PartState.needsRepair => (
        Icons.build_circle_outlined,
        Colors.orange.shade100,
        Colors.orange.shade900,
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

    return StateBadge(
      label: state.toFrenchLabel(),
      icon: icon,
      background: background,
      foreground: foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
