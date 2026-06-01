import 'package:flutter/material.dart';

import '../../repositories/tag_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import 'tag_chip.dart';

class TagCreationDialog extends StatefulWidget {
  final Future<void> Function(String name, String color) onCreate;

  const TagCreationDialog({super.key, required this.onCreate});

  @override
  State<TagCreationDialog> createState() => _TagCreationDialogState();
}

class _TagCreationDialogState extends State<TagCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedColor = TagPalette.defaultColor;
  String? _submitError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer une étiquette'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom'),
                maxLength: ValidationConstants.tagNameMaxLength,
                validator: _validateName,
                onChanged: (_) => setState(() => _submitError = null),
              ),
              const SizedBox(height: 12),
              Text('Couleur', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in TagPalette.options)
                    Semantics(
                      label: 'Couleur ${option.label}',
                      selected: _selectedColor == option.hex,
                      button: true,
                      child: FilterChip(
                        label: Text(option.label),
                        avatar: CircleAvatar(
                          backgroundColor: option.color,
                          child: _selectedColor == option.hex
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: TagPalette.textColorFor(option.color),
                                )
                              : null,
                        ),
                        selected: _selectedColor == option.hex,
                        onSelected: (_) {
                          setState(() => _selectedColor = option.hex);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TagChip(
                name: _nameController.text.trim().isEmpty
                    ? 'Aperçu'
                    : _nameController.text.trim(),
                color: TagPalette.colorFromHex(_selectedColor),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Le nom de l\'étiquette est requis';
    if (name.length < ValidationConstants.tagNameMinLength) {
      return 'Le nom de l\'étiquette doit contenir au moins 2 caractères';
    }
    if (name.length > ValidationConstants.tagNameMaxLength) {
      return 'Le nom de l\'étiquette doit contenir 30 caractères maximum';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onCreate(_nameController.text.trim(), _selectedColor);
      if (mounted) Navigator.of(context).pop(true);
    } on TagRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitError = error.message;
          _isSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitError = 'Impossible de créer l\'étiquette. Réessayez.';
          _isSubmitting = false;
        });
      }
    }
  }
}
