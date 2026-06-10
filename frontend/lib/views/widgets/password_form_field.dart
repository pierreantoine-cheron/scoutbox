import 'package:flutter/material.dart';

/// A reusable password input field with visibility toggle.
///
/// Manages its own visibility state internally while exposing
/// all necessary TextFormField configuration options.
///
/// Uses the theme's [InputDecorationTheme] for border styling.
class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final AutovalidateMode autovalidateMode;
  final String? labelText;
  final String? hintText;
  final String? showPasswordTooltip;
  final String? hidePasswordTooltip;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final FormFieldValidator<String>? validator;

  const PasswordFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.labelText,
    this.hintText,
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
        hintText: widget.hintText,
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
          icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
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
