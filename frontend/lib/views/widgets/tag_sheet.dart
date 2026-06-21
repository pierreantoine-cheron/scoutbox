import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../repositories/tag_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/design_constants.dart';
import 'sheet_scaffold.dart';

class TagSheet extends StatefulWidget {
  final String? initialName;
  final String? initialColor;
  final Future<void> Function(String name, String color) onSave;

  const TagSheet({
    super.key,
    this.initialName,
    this.initialColor,
    required this.onSave,
  });

  @override
  State<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<TagSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedColorKey;
  String _customHex = '';
  String? _submitError;
  bool _isSubmitting = false;

  bool get _isCreate => widget.initialName == null;
  String get _saveLabel => _isCreate ? 'Créer' : 'Enregistrer';
  String get _title => _isCreate ? 'Nouvelle étiquette' : "Modifier l'étiquette";

  bool get _isSaveEnabled {
    final name = _nameController.text.trim();
    if (_isCreate) {
      return name.length >= ValidationConstants.tagNameMinLength;
    }
    return name.isNotEmpty &&
        (name != widget.initialName || _effectiveColor != widget.initialColor);
  }

  bool get _isCustomSelected => _selectedColorKey == 'Personnalisée';

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialColor != null) {
      _initColorFromHex(widget.initialColor!);
    } else {
      _selectedColorKey = TagPalette.options.first.label;
      _customHex = TagPalette.options.first.hex;
    }
  }

  void _initColorFromHex(String hex) {
    for (final option in TagPalette.options) {
      if (option.hex.toUpperCase() == hex.toUpperCase()) {
        _selectedColorKey = option.label;
        return;
      }
    }
    _selectedColorKey = 'Personnalisée';
    _customHex = hex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _effectiveColor => _isCustomSelected ? _customHex : _presetHex;

  String get _presetHex {
    for (final option in TagPalette.options) {
      if (option.label == _selectedColorKey) return option.hex;
    }
    return TagPalette.defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNameField(theme.colorScheme),
            const SizedBox(height: 16),
            _buildColorLabel(theme.colorScheme),
            const SizedBox(height: 8),
            _buildColorGrid(theme.colorScheme),
            if (_isCustomSelected) ...[
              const SizedBox(height: 8),
              _buildCustomColorPicker(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nom',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _nameController,
          autofocus: true,
          maxLength: ValidationConstants.tagNameMaxLength,
          decoration: const InputDecoration(
            hintText: 'Nom de l\'étiquette',
            counterStyle: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.muted,
            ),
          ),
          validator: _validateName,
          onChanged: (_) => setState(() => _submitError = null),
        ),
      ],
    );
  }

  Widget _buildColorLabel(ColorScheme colorScheme) {
    return Text(
      'Couleur',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildColorGrid(ColorScheme colorScheme) {
    final allOptions = [
      ...TagPalette.options,
      const TagPaletteOption(
        label: 'Personnalisée',
        hex: '',
        color: Colors.transparent,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: allOptions.length,
      itemBuilder: (context, index) {
        final option = allOptions[index];
        if (option.label == 'Personnalisée') {
          return _buildCustomColorSwatch(colorScheme);
        }
        return _buildColorSwatch(option, colorScheme);
      },
    );
  }

  Widget _buildColorSwatch(TagPaletteOption option, ColorScheme colorScheme) {
    final isSelected = _selectedColorKey == option.label;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedColorKey = option.label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: option.color,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isSelected ? colorScheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: TagPalette.textColorFor(option.color),
                size: 18,
              )
            : null,
      ),
    );
  }

  Widget _buildCustomColorSwatch(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        if (_customHex.isEmpty) {
          _customHex = TagPalette.defaultColor;
        }
        setState(() => _selectedColorKey = 'Personnalisée');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: _isCustomSelected ? colorScheme.onSurface : AppColors.border,
            width: 2.5,
          ),
          boxShadow: _isCustomSelected
              ? [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: _isCustomSelected
            ? const Icon(Icons.colorize, size: 18)
            : const Icon(Icons.colorize, size: 18, color: AppColors.muted),
      ),
    );
  }

  Widget _buildCustomColorPicker() {
    final currentColor = _customHex.isNotEmpty
        ? TagPalette.colorFromHex(_customHex)
        : TagPalette.colorFromHex(TagPalette.defaultColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                _customHex = _colorToHex(color);
              });
            },
            enableAlpha: false,
            portraitOnly: true,
            displayThumbColor: true,
            labelTypes: const [],
            colorPickerWidth: constraints.maxWidth,
          );
        },
      ),
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

  /// flutter_colorpicker toHexString extension method is broken
  String _colorToHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}${g.toRadixString(16).padLeft(2, '0').toUpperCase()}${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onSave(_nameController.text.trim(), _effectiveColor);
      if (mounted) Navigator.of(context).pop(true);
    } on TagRepositoryException catch (error) {
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
              ? 'Impossible de créer l\'étiquette. Réessayez.'
              : 'Impossible de modifier l\'étiquette. Réessayez.';
          _isSubmitting = false;
        });
      }
    }
  }
}
