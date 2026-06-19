import 'package:flutter/material.dart';

import '../../models/tent_model.dart';
import '../../utils/design_constants.dart';
import 'sheet_scaffold.dart';

class ModelPickerSheet extends StatelessWidget {
  final String title;
  final List<TentModel> models;
  final String currentModelId;
  final void Function(String) onSelected;
  final VoidCallback onCancel;

  const ModelPickerSheet({
    super.key,
    required this.title,
    required this.models,
    required this.currentModelId,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetScaffold(
      title: title,
      onCancel: onCancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: models.map((model) {
          final isCurrent = model.id == currentModelId;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InkWell(
              onTap: isCurrent ? null : () => onSelected(model.id),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: isCurrent ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
