import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/design_constants.dart';
import 'app_progress_indicator.dart';
import 'sheet_scaffold.dart';

class AddPartSheet extends ConsumerStatefulWidget {
  final String tentId;
  final Set<String> existingPartKindIds;

  const AddPartSheet({
    super.key,
    required this.tentId,
    required this.existingPartKindIds,
  });

  @override
  ConsumerState<AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends ConsumerState<AddPartSheet> {
  late Set<String> _selectedIds;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.existingPartKindIds};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(partManagementProvider(widget.tentId).notifier).loadPartKinds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partManagementProvider(widget.tentId));
    final theme = Theme.of(context);

    return SheetScaffold(
      title: 'Modifier les \u00e9l\u00e9ments',
      errorMessage: _errorMessage,
      isLoading: _isSaving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _onSave,
      child: _buildPartKindList(state, theme),
    );
  }

  Widget _buildPartKindList(PartManagementState state, ThemeData theme) {
    if (state.isLoadingPartKinds) {
      return const Center(child: AppProgressIndicator());
    }

    if (state.partKindsError != null) {
      return Center(
        child: Text(
          state.partKindsError!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    final partKinds = state.partKinds.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    if (partKinds.isEmpty) {
      return const Center(child: Text('Aucun \u00e9l\u00e9ment disponible.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: partKinds.length,
      itemBuilder: (context, index) {
        final pk = partKinds[index];
        final isSelected = _selectedIds.contains(pk.id);

        return InkWell(
          onTap: _isSaving ? null : () => _togglePartKind(pk.id),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pk.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _togglePartKind(String partKindId) {
    setState(() {
      _errorMessage = null;
      if (_selectedIds.contains(partKindId)) {
        _selectedIds.remove(partKindId);
      } else {
        _selectedIds.add(partKindId);
      }
    });
  }

  Future<void> _onSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final toAdd = _selectedIds
          .where((id) => !widget.existingPartKindIds.contains(id))
          .toList();
      final toRemove = widget.existingPartKindIds
          .where((id) => !_selectedIds.contains(id))
          .toList();

      if (toAdd.isEmpty && toRemove.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final repository = ref.read(tentRepositoryProvider);

      if (toAdd.isNotEmpty) {
        await repository.addPartsToTent(
          tentId: widget.tentId,
          partKindIds: toAdd,
        );
      }

      if (toRemove.isNotEmpty) {
        final partsAsync = ref.read(tentDetailProvider(widget.tentId));
        final parts = partsAsync.asData?.value.parts ?? [];
        for (final partKindId in toRemove) {
          final part = parts
              .where((p) => p.partKindId == partKindId)
              .firstOrNull;
          if (part != null) {
            await repository.removePart(partId: part.id);
          }
        }
      }

      if (!mounted) return;

      ref.invalidate(tentDetailProvider(widget.tentId));
      invalidateTentHistory(ref, widget.tentId);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      final message = error is TentRepositoryException
          ? error.message
          : 'Impossible de modifier les \u00e9l\u00e9ments. R\u00e9essayez.';
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
