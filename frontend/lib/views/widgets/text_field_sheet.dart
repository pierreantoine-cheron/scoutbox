import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';
import 'sheet_handle.dart';

class TextFieldSheet extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey<FormState>? formKey;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final String? Function(String?)? validator;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const TextFieldSheet({
    super.key,
    required this.title,
    required this.controller,
    required this.focusNode,
    this.formKey,
    required this.label,
    this.keyboardType,
    this.maxLength,
    this.maxLines,
    this.validator,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<TextFieldSheet> createState() => _TextFieldSheetState();
}

class _TextFieldSheetState extends State<TextFieldSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Form(
              key: widget.formKey,
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: widget.keyboardType,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines ?? 1,
                minLines: widget.maxLines ?? 1,
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                ),
                textInputAction:
                    (widget.maxLines ?? 1) > 1 ? TextInputAction.newline : TextInputAction.done,
                onFieldSubmitted: (widget.maxLines ?? 1) > 1
                    ? null
                    : (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).pop(true);
                      }),
                validator: widget.validator ??
                    (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Ce champ est requis';
                      }
                      return null;
                    },
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
