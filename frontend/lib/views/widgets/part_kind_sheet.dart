import 'package:flutter/material.dart';

import '../../repositories/part_kind_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/constants.dart';
import 'sheet_scaffold.dart';

class PartKindSheet extends StatefulWidget {
  final String? initialName;
  final Future<void> Function(String name) onSave;

  const PartKindSheet({
    super.key,
    this.initialName,
    required this.onSave,
  });

  @override
  State<PartKindSheet> createState() => _PartKindSheetState();
}

class _PartKindSheetState extends State<PartKindSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _submitError;
  bool _isSubmitting = false;

  bool get _isCreate => widget.initialName == null;
  String get _saveLabel => _isCreate ? 'Créer' : 'Enregistrer';
  String get _title => _isCreate ? 'Nouvel élément' : "Modifier l'élément";

  bool get _isSaveEnabled =>
      _nameController.text.trim().isNotEmpty &&
      (_isCreate || _nameController.text.trim() != widget.initialName);

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _title,
      errorMessage: _submitError,
      isLoading: _isSubmitting,
      saveEnabled: _isSaveEnabled,
      saveLabel: _saveLabel,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          maxLength: ValidationConstants.partKindNameMaxLength,
          decoration: const InputDecoration(
            hintText: 'Nom de l\'élément',
          ),
          validator: _validateName,
          onChanged: (_) => setState(() => _submitError = null),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Le nom de l\'élément est requis';
    if (name.length > ValidationConstants.partKindNameMaxLength) {
      return 'Le nom de l\'élément est trop long (60 max)';
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
      await widget.onSave(_nameController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on PartKindRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _submitError = ErrorLocalizer.localize(
            error.code,
            fallback: error.message,
          );
          _isSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitError = _isCreate
              ? 'Impossible de créer l\'élément. Réessayez.'
              : 'Impossible de renommer l\'élément. Réessayez.';
          _isSubmitting = false;
        });
      }
    }
  }
}
