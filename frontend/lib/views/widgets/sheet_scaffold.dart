import 'package:flutter/material.dart';

import 'sheet_footer.dart';
import 'sheet_handle.dart';

class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final bool isLoading;
  final bool saveEnabled;
  final String cancelLabel;
  final String saveLabel;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.errorMessage,
    this.onCancel,
    this.onSave,
    this.isLoading = false,
    this.saveEnabled = true,
    this.cancelLabel = 'Annuler',
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
          ),
          const SizedBox(height: 8),
          SheetFooter(
            isLoading: isLoading,
            saveEnabled: saveEnabled,
            onCancel: onCancel,
            onSave: onSave,
            cancelLabel: cancelLabel,
            saveLabel: saveLabel,
          ),
        ],
      ),
    );
  }
}
