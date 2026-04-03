import 'package:flutter/material.dart';

/// A reusable password input field with visibility toggle.
///
/// Manages its own visibility state internally while exposing
/// all necessary TextFormField configuration options.
class PasswordFormField extends StatefulWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Focus node for the text field
  final FocusNode? focusNode;

  /// Autovalidate mode for the field
  final AutovalidateMode autovalidateMode;

  /// Label text for the input decoration
  final String labelText;

  /// Hint text for the tooltip when password is obscured
  final String? showPasswordTooltip;

  /// Hint text for the tooltip when password is visible
  final String? hidePasswordTooltip;

  /// Autofill hint for the field (defaults to password)
  final Iterable<String>? autofillHints;

  /// Text input action for the field
  final TextInputAction? textInputAction;

  /// Callback when field is submitted
  final ValueChanged<String>? onFieldSubmitted;

  /// Callback when editing is complete
  final VoidCallback? onEditingComplete;

  /// Validator function
  final FormFieldValidator<String>? validator;

  const PasswordFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autovalidateMode = AutovalidateMode.disabled,
    required this.labelText,
    this.showPasswordTooltip,
    this.hidePasswordTooltip,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.validator,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autovalidateMode: widget.autovalidateMode,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
          icon: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
          ),
          tooltip: _obscureText
              ? (widget.showPasswordTooltip ?? 'Afficher le mot de passe')
              : (widget.hidePasswordTooltip ?? 'Masquer le mot de passe'),
        ),
      ),
      obscureText: _obscureText,
      autofillHints: widget.autofillHints,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onEditingComplete: widget.onEditingComplete,
      validator: widget.validator,
    );
  }
}
