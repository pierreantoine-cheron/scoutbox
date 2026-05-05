import 'package:flutter/material.dart';

class InlineTextEditor extends StatefulWidget {
  final String value;
  final bool isEditing;
  final bool isEnabled;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final double? editorWidth;
  final bool dense;
  final String? Function(String value) validator;
  final void Function(String value) onConfirm;
  final VoidCallback onStartEditing;
  final VoidCallback onCancel;
  final Widget Function(BuildContext context, VoidCallback startEditing)
  readOnlyBuilder;

  const InlineTextEditor({
    super.key,
    required this.value,
    required this.isEditing,
    required this.isEnabled,
    required this.validator,
    required this.onConfirm,
    required this.onStartEditing,
    required this.onCancel,
    required this.readOnlyBuilder,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.editorWidth,
    this.dense = false,
  });

  @override
  State<InlineTextEditor> createState() => _InlineTextEditorState();
}

class _InlineTextEditorState extends State<InlineTextEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(InlineTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.value;
    widget.onStartEditing();
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    _controller.text = widget.value;
    widget.onCancel();
  }

  void _confirm() {
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() {});
      return;
    }

    widget.onConfirm(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return widget.readOnlyBuilder(
        context,
        widget.isEnabled ? _startEditing : () {},
      );
    }

    final error = widget.validator(_controller.text);
    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: error,
        border: const OutlineInputBorder(),
        isDense: widget.dense,
      ),
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _confirm(),
    );

    final field = widget.editorWidth == null
        ? Expanded(child: textField)
        : SizedBox(width: widget.editorWidth, child: textField);

    return Row(
      mainAxisSize: widget.editorWidth == null
          ? MainAxisSize.max
          : MainAxisSize.min,
      children: [
        field,
        SizedBox(width: widget.dense ? 0 : 8),
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Valider',
          visualDensity: widget.dense ? VisualDensity.compact : null,
          onPressed: error == null ? _confirm : null,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Annuler',
          visualDensity: widget.dense ? VisualDensity.compact : null,
          onPressed: _cancelEditing,
        ),
      ],
    );
  }
}
