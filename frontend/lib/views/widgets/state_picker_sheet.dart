import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';
import 'sheet_handle.dart';
import 'state_badge.dart';

class StatePickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T currentValue;
  final StateBadgeStyle Function(BuildContext, T) styleFor;
  final void Function(T) onSelected;
  final VoidCallback onCancel;

  const StatePickerSheet({
    super.key,
    required this.title,
    required this.values,
    required this.currentValue,
    required this.styleFor,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...values.map((value) {
          final style = styleFor(context, value);
          final isCurrent = value == currentValue;

          return InkWell(
            onTap: () => onSelected(value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3)
                    : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(style.icon, size: 20, color: style.foreground),
                  const SizedBox(width: 10),
                  Text(
                    style.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: style.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isCurrent) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
