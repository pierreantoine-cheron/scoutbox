import 'package:flutter/material.dart';

import 'sheet_footer.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool isDestructive = false,
  bool barrierDismissible = true,
  bool enabled = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final theme = Theme.of(ctx);

      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: SheetFooter.outlinedStyle(theme),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? SheetFooter.filledStyle(theme).merge(
                    FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                  )
                : SheetFooter.filledStyle(theme),
            onPressed: enabled ? () => Navigator.of(ctx).pop(true) : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<void> showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
