import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/part_kind.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/app_colors.dart';
import 'part_kind_row.dart';
import 'sheet_scaffold.dart';

class TentModelSheet extends ConsumerStatefulWidget {
  final String? initialName;
  final List<String>? initialComponentIds;
  final Future<void> Function(String name, List<String> componentIds) onSave;

  const TentModelSheet({
    super.key,
    this.initialName,
    this.initialComponentIds,
    required this.onSave,
  });

  @override
  ConsumerState<TentModelSheet> createState() => _TentModelSheetState();
}

class _TentModelSheetState extends ConsumerState<TentModelSheet> {
  final _nameController = TextEditingController();
  final Set<String> _selectedPartKindIds = {};
  String? _submitError;
  bool _isSubmitting = false;

  bool get _isCreate => widget.initialName == null;
  String get _saveLabel => _isCreate ? 'Créer' : 'Enregistrer';
  String get _title => _isCreate ? 'Nouveau modèle' : 'Modifier le modèle';

  bool get _isSaveEnabled {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    if (!_isCreate) {
      final nameUnchanged = name == widget.initialName;
      final partsUnchanged =
          _selectedPartKindIds.length == (widget.initialComponentIds?.length ?? 0) &&
          (widget.initialComponentIds?.every((id) => _selectedPartKindIds.contains(id)) ?? false);
      if (nameUnchanged && partsUnchanged) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialComponentIds != null) {
      _selectedPartKindIds.addAll(widget.initialComponentIds!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNameField(theme.colorScheme),
          const SizedBox(height: 16),
          _buildPartsLabel(theme.colorScheme),
          const SizedBox(height: 8),
          _buildPartsList(),
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
          maxLength: 60,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
            return Text(
              '$currentLength / $maxLength',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.muted,
              ),
            );
          },
          decoration: const InputDecoration(
            hintText: 'Nom du modèle',
          ),
          onChanged: (_) => setState(() => _submitError = null),
        ),
      ],
    );
  }

  Widget _buildPartsLabel(ColorScheme colorScheme) {
    return Text(
      'Éléments par défaut',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildPartsList() {
    final partKindsState = ref.watch(partKindsProvider);

    return partKindsState.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Impossible de charger les éléments.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (partKinds) => LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: partKinds.length,
              itemBuilder: (context, index) => _buildPartRow(partKinds[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartRow(PartKind pk) {
    final selected = _selectedPartKindIds.contains(pk.id);

    return PartKindRow(
      partKind: pk,
      isSelected: selected,
      onTap: () {
        setState(() {
          if (selected) {
            _selectedPartKindIds.remove(pk.id);
          } else {
            _selectedPartKindIds.add(pk.id);
          }
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_isSaveEnabled) return;

    setState(() {
      _submitError = null;
      _isSubmitting = true;
    });

    try {
      await widget.onSave(_nameController.text.trim(), _selectedPartKindIds.toList());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on TentRepositoryException catch (error) {
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
              ? 'Impossible de créer le modèle. Réessayez.'
              : 'Impossible de modifier le modèle. Réessayez.';
          _isSubmitting = false;
        });
      }
    }
  }
}
