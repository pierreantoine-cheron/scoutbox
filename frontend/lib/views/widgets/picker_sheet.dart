import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';
import 'sheet_scaffold.dart';

class PickerItem<T> {
  final T value;
  final String label;
  final Color? color;
  final IconData? icon;

  const PickerItem({
    required this.value,
    required this.label,
    this.color,
    this.icon,
  });
}

class PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<PickerItem<T>> items;
  final T currentValue;
  final void Function(T) onSelected;
  final VoidCallback onCancel;

  const PickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.currentValue,
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
        children: items.map((item) {
          final selected = item.value == currentValue;

          return InkWell(
            onTap: () => onSelected(item.value),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 20, color: item.color),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: item.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
