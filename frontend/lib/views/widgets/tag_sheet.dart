import 'package:flutter/material.dart';

import '../../repositories/tag_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/design_constants.dart';
import 'sheet_footer.dart';

class TagSheet extends StatefulWidget {
  final Future<void> Function(String name, String color) onCreate;

  const TagSheet({super.key, required this.onCreate});

  @override
  State<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<TagSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customHexController = TextEditingController();
  String? _selectedColorKey;
  String _customHex = '';
  String? _submitError;
  bool _isSubmitting = false;

  bool get _isSaveEnabled =>
      _nameController.text.trim().length >=
      ValidationConstants.tagNameMinLength;

  @override
  void initState() {
    super.initState();
    _selectedColorKey = TagPalette.options.first.label;
    _customHexController.text = TagPalette.options.first.hex;
    _customHex = TagPalette.options.first.hex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customHexController.dispose();
    super.dispose();
  }

  String get _effectiveColor =>
      (_selectedColorKey == 'Personnalisée') ? _customHex : _presetHex;

  String get _presetHex {
    for (final option in TagPalette.options) {
      if (option.label == _selectedColorKey) return option.hex;
    }
    return TagPalette.defaultColor;
  }

  Color get _effectiveColorValue => TagPalette.colorFromHex(_effectiveColor);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(context),
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNameField(colorScheme),
                      const SizedBox(height: 16),
                      _buildColorLabel(colorScheme),
                      const SizedBox(height: 8),
                      _buildColorGrid(colorScheme),
                      const SizedBox(height: 12),
                      _buildCustomColorRow(colorScheme),
                      const SizedBox(height: 12),
                      _buildPreview(colorScheme),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _submitError!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SheetFooter(
              isLoading: _isSubmitting,
              saveEnabled: _isSaveEnabled,
              saveLabel: 'Créer',
              onCancel: () => Navigator.of(context).pop(),
              onSave: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Nouvelle étiquette',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.muted,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
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
          decoration: const InputDecoration(hintText: 'Nom de l\'étiquette'),
          validator: _validateName,
          onChanged: (_) => setState(() => _submitError = null),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_nameController.text.length} / ${ValidationConstants.tagNameMaxLength}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.muted,
            ),
          ),
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
    final isSelected = _selectedColorKey == 'Personnalisée';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorKey = 'Personnalisée';
          if (_customHex.isEmpty) {
            _customHex = TagPalette.defaultColor;
            _customHexController.text = TagPalette.defaultColor;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isSelected ? colorScheme.onSurface : AppColors.border,
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
            ? const Icon(Icons.colorize, size: 18)
            : Icon(Icons.colorize, size: 18, color: AppColors.muted),
      ),
    );
  }

  Widget _buildCustomColorRow(ColorScheme colorScheme) {
    final colorPreview = _effectiveColorValue;

    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedColorKey = 'Personnalisée'),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorPreview,
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedColorKey == 'Personnalisée'
                    ? colorScheme.onSurface
                    : AppColors.border,
                width: _selectedColorKey == 'Personnalisée' ? 2.5 : 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _customHexController,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: AppColors.muted,
            ),
            decoration: const InputDecoration(
              hintText: '#RRGGBB',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (value) {
              final normalized = value.startsWith('#') ? value : '#$value';
              if (_isValidHex(normalized) || value.isEmpty) {
                setState(() {
                  _customHex = normalized;
                  _selectedColorKey = 'Personnalisée';
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme colorScheme) {
    final color = _effectiveColorValue;
    final name = _nameController.text.trim().isEmpty
        ? 'Aperçu'
        : _nameController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: TagPalette.textColorFor(color),
              ),
            ),
          ),
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

  bool _isValidHex(String value) {
    if (!value.startsWith('#')) return false;
    final hex = value.substring(1);
    return hex.length == 6 && int.tryParse(hex, radix: 16) != null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedColorKey == 'Personnalisée' && !_isValidHex(_customHex)) {
      setState(() => _submitError = 'Format de couleur invalide (ex: #1A70E5)');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onCreate(_nameController.text.trim(), _effectiveColor);
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
