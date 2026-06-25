import 'package:flutter/material.dart';

import '../../models/part_kind.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';

class PartKindRow extends StatelessWidget {
  final PartKind partKind;
  final bool isSelected;
  final VoidCallback? onTap;

  const PartKindRow({
    super.key,
    required this.partKind,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentSoft : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isSelected ? AppColors.scoutGreen : AppColors.border,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                partKind.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
