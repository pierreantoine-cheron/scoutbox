import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';

class SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const SectionLabel({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
