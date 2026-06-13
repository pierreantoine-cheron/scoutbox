import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';

class SheetFooter extends StatelessWidget {
  final bool isLoading;
  final bool saveEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final String cancelLabel;
  final String saveLabel;

  const SheetFooter({
    super.key,
    this.isLoading = false,
    this.saveEnabled = true,
    this.onCancel,
    this.onSave,
    this.cancelLabel = 'Annuler',
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isLoading ? null : onCancel,
                style: _outlinedStyle(theme),
                child: Text(cancelLabel),
              ),
              if (onSave != null) ...[
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: (isLoading || !saveEnabled) ? null : onSave,
                  style: _filledStyle(theme),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(saveLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static ButtonStyle _outlinedStyle(ThemeData theme) {
    return OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  static ButtonStyle _filledStyle(ThemeData theme) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}
