import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'state_badge.dart';

class CompactStateBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const CompactStateBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  factory CompactStateBadge.forTent(
    BuildContext context,
    TentOverallState state,
  ) {
    final style = tentStateBadgeStyle(context, state);

    return CompactStateBadge(
      label: style.label,
      icon: style.icon,
      background: style.background,
      foreground: style.foreground,
    );
  }

  factory CompactStateBadge.forPart(BuildContext context, PartState state) {
    final style = partStateBadgeStyle(context, state);

    return CompactStateBadge(
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ).copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
