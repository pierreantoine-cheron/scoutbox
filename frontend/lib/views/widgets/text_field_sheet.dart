import 'package:flutter/material.dart';

import 'sheet_scaffold.dart';

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
    return SheetScaffold(
      title: widget.title,
      onCancel: widget.onCancel,
      onSave: widget.onSave,
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
    );
  }
}
