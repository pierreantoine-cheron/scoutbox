import 'package:flutter/material.dart';

import '../../utils/error_messages.dart';
import 'confirm_dialog.dart';

Future<void> showDeleteConfirmation({
  required BuildContext context,
  required String title,
  required String content,
  required String errorMessage,
  required Future<void> Function() onDelete,
  required VoidCallback onSuccess,
  bool enabled = true,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: title,
    content: content,
    confirmLabel: 'Supprimer',
    isDestructive: true,
    enabled: enabled,
  );

  if (!confirmed) return;

  try {
    await onDelete();
    onSuccess();
  } catch (error) {
    if (context.mounted) {
      showErrorDialog(context, toUserFacingError(error, errorMessage));
    }
  }
}
