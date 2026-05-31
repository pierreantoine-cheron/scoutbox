import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/constants.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../../utils/tent_validators.dart';
import '../widgets/add_part_sheet.dart';
import '../widgets/tent_history_section.dart';
import '../widgets/widgets.dart';

class TentDetailScreen extends ConsumerStatefulWidget {
  final String tentId;

  const TentDetailScreen({super.key, required this.tentId});

  @override
  ConsumerState<TentDetailScreen> createState() => _TentDetailScreenState();
}

class _TentDetailScreenState extends ConsumerState<TentDetailScreen>
    with RouteAware, RouteAwareAppBarMixin<TentDetailScreen> {
  DateTime? _lastSeenSaveTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscribeRouteObserver();
    dispatchAppBarConfig();
  }

  @override
  void dispose() {
    unsubscribeRouteObserver();
    super.dispose();
  }

  @override
  void didPush() {
    dispatchAppBarConfig();
  }

  @override
  AppBarConfig buildAppBarConfig() {
    if (!mounted) return const AppBarConfig(screenId: '');

    return const AppBarConfig(
      screenId: 'tent_detail',
      title: Text('Détail de la tente'),
      showBackButton: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tentAsync = ref.watch(tentDetailProvider(widget.tentId));
    final editState = ref.watch(tentEditProvider(widget.tentId));

    if (editState.lastSaveTime != null &&
        editState.lastSaveTime != _lastSeenSaveTime) {
      _lastSeenSaveTime = editState.lastSaveTime;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(successIndicatorProvider.notifier).fire();
      });
    }

    return Material(
      child: SafeArea(
        child: tentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            message: _toErrorMessage(error),
            onRetry: () => ref.invalidate(tentDetailProvider(widget.tentId)),
          ),
          data: (tent) => _DetailContent(tentId: widget.tentId, tent: tent),
        ),
      ),
    );
  }

  String _toErrorMessage(Object error) {
    if (error is TentRepositoryException) {
      return error.message;
    }

    return 'Impossible de charger le détail de la tente.';
  }
}

class _DetailContent extends ConsumerWidget {
  final String tentId;
  final Tent tent;

  const _DetailContent({required this.tentId, required this.tent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editState = ref.watch(tentEditProvider(tentId));
    final useLocalTent =
        editState.baseTent?.id == tentId &&
        (editState.editingField != null || editState.savingField != null);
    final displayedTent = useLocalTent ? editState.baseTent! : tent;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 960 : double.infinity),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderSection(
                tentId: tentId,
                tent: displayedTent,
                editState: editState,
              ),
              const SizedBox(height: 16),
              _CommentsSection(
                tentId: tentId,
                tent: displayedTent,
                editState: editState,
              ),
              const SizedBox(height: 16),
              _PartsSection(
                tentId: tentId,
                parts: displayedTent.parts,
                isArchived: displayedTent.isArchived,
              ),
              const SizedBox(height: 16),
              TentHistorySection(tentId: tentId),
              if (editState.fieldError != null) ...[
                const SizedBox(height: 12),
                _FieldErrorBanner(
                  message: editState.fieldError!,
                  onRetry: editState.pendingRetry == null
                      ? null
                      : () => ref
                            .read(tentEditProvider(tentId).notifier)
                            .retryLastUpdate(),
                  onDismiss: () =>
                      ref.read(tentEditProvider(tentId).notifier).clearError(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _HeaderSection({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditableNameField(
              tentId: tentId,
              tent: tent,
              editState: editState,
            ),
            if (tent.isArchived) ...[
              const SizedBox(height: 8),
              const Chip(
                avatar: Icon(Icons.archive_outlined),
                label: Text('Archivée'),
              ),
            ],
            const SizedBox(height: 12),
            Opacity(
              opacity: tent.isArchived ? 0.55 : 1,
              child: IgnorePointer(
                ignoring: tent.isArchived,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EditableOverallStateSelector(
                      tentId: tentId,
                      tent: tent,
                      editState: editState,
                    ),
                    _EditableSizeField(
                      tentId: tentId,
                      tent: tent,
                      editState: editState,
                    ),
                    _InfoChip(
                      icon: Icons.terrain_outlined,
                      label: _modelLabel(tent.tentModelName),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ArchiveTentButton(tentId: tentId, isArchived: tent.isArchived),
          ],
        ),
      ),
    );
  }

  String _modelLabel(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Type inconnu';
    }

    return normalized;
  }
}

class _ArchiveTentButton extends ConsumerStatefulWidget {
  final String tentId;
  final bool isArchived;

  const _ArchiveTentButton({required this.tentId, required this.isArchived});

  @override
  ConsumerState<_ArchiveTentButton> createState() => _ArchiveTentButtonState();
}

class _ArchiveTentButtonState extends ConsumerState<_ArchiveTentButton> {
  bool _isArchiving = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Archiver la tente',
      child: OutlinedButton.icon(
        onPressed: widget.isArchived || _isArchiving ? null : _onArchivePressed,
        icon: _isArchiving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.archive_outlined),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        label: const Text('Archiver'),
      ),
    );
  }

  Future<void> _onArchivePressed() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Archiver la tente',
      content: 'Archiver cette tente ? Elle n\'apparaîtra plus dans la liste mais restera dans l\'historique.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isArchiving = true;
    });

    try {
      final archivedTent = await ref
          .read(tentRepositoryProvider)
          .archiveTent(widget.tentId);
      invalidateTentHistory(ref, widget.tentId);
      ref.read(tentListProvider.notifier).hideTent(archivedTent.id);
      ref.read(successIndicatorProvider.notifier).fire();

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        final message = e is TentRepositoryException
            ? e.message
            : 'Impossible d\'archiver la tente. Réessayez.';
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isArchiving = false;
        });
      }
    }
  }
}

class _EditableNameField extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _EditableNameField({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InlineTextEditor(
      value: tent.name,
      isEditing: editState.editingField == EditableField.name,
      isEnabled: !tent.isArchived,
      labelText: 'Nom',
      hintText: 'Nom de la tente',
      validator: _validateName,
      onStartEditing: () => ref
          .read(tentEditProvider(tentId).notifier)
          .startEditing(EditableField.name, tent),
      onCancel: () =>
          ref.read(tentEditProvider(tentId).notifier).cancelEditing(),
      onConfirm: (name) => ref
          .read(tentEditProvider(tentId).notifier)
          .updateField(
            tentId: tentId,
            name: name,
            size: tent.size,
            overallState: tent.overallState,
            comments: tent.comments,
          ),
      readOnlyBuilder: (context, startEditing) {
        final theme = Theme.of(context);
        return InkWell(
          onTap: tent.isArchived ? null : startEditing,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(tent.name, style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _validateName(String value) => TentValidators.validateName(value);
}

class _EditableSizeField extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _EditableSizeField({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InlineTextEditor(
      value: tent.size.toString(),
      isEditing: editState.editingField == EditableField.size,
      isEnabled: !tent.isArchived,
      labelText: 'Taille',
      hintText: 'Nombre de places',
      keyboardType: TextInputType.number,
      editorWidth: 120,
      dense: true,
      validator: _validateSize,
      onStartEditing: () => ref
          .read(tentEditProvider(tentId).notifier)
          .startEditing(EditableField.size, tent),
      onCancel: () =>
          ref.read(tentEditProvider(tentId).notifier).cancelEditing(),
      onConfirm: (value) => ref
          .read(tentEditProvider(tentId).notifier)
          .updateField(
            tentId: tentId,
            name: tent.name,
            size: int.parse(value),
            overallState: tent.overallState,
            comments: tent.comments,
          ),
      readOnlyBuilder: (context, startEditing) {
        return InkWell(
          onTap: tent.isArchived ? null : startEditing,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InfoChip(
                  icon: Icons.people_outline,
                  label: tent.size == 1 ? '1 place' : '${tent.size} places',
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _validateSize(String value) => TentValidators.validateSize(value);
}

class _EditableOverallStateSelector extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _EditableOverallStateSelector({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tentEditProvider(tentId).notifier);

    return StateSelector<TentOverallState>(
      values: TentOverallState.values,
      selectedValue: tent.overallState,
      enabled: !tent.isArchived,
      styleFor: tentStateBadgeStyle,
      selectedBadgeBuilder: StateBadge.forTent,
      onSelected: (state) {
        notifier.updateField(
          tentId: tentId,
          name: tent.name,
          size: tent.size,
          overallState: state,
          comments: tent.comments,
        );
      },
    );
  }
}

class _CommentsSection extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _CommentsSection({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = editState.editingField == EditableField.comments;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commentaires',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InlineTextEditor(
              value: tent.comments ?? '',
              isEditing: isEditing,
              isEnabled: !tent.isArchived,
              hintText: 'Ajouter un commentaire...',
              maxLength: ValidationConstants.tentCommentsMaxLength,
              minLines: 2,
              maxLines: 4,
              validator: _validateComments,
              onStartEditing: () => ref
                  .read(tentEditProvider(tentId).notifier)
                  .startEditing(EditableField.comments, tent),
              onCancel: () =>
                  ref.read(tentEditProvider(tentId).notifier).cancelEditing(),
              onConfirm: (value) => ref
                  .read(tentEditProvider(tentId).notifier)
                  .updateField(
                    tentId: tentId,
                    name: tent.name,
                    size: tent.size,
                    overallState: tent.overallState,
                    comments: value.isEmpty ? null : value,
                  ),
              readOnlyBuilder: (context, startEditing) {
                return InkWell(
                  onTap: tent.isArchived ? null : startEditing,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(_displayText(tent.comments))),
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _displayText(String? comments) {
    final normalized = comments?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Aucun commentaire';
    }
    return normalized;
  }

  String? _validateComments(String value) =>
      TentValidators.validateComments(value);
}

class _PartsSection extends ConsumerStatefulWidget {
  final String tentId;
  final List<Part> parts;
  final bool isArchived;

  const _PartsSection({
    required this.tentId,
    required this.parts,
    required this.isArchived,
  });

  @override
  ConsumerState<_PartsSection> createState() => _PartsSectionState();
}

class _PartsSectionState extends ConsumerState<_PartsSection> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPartIds = {};
  String? _editingCommentPartId;

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPartIds.clear();
    });
  }

  void _togglePartSelection(String partId) {
    setState(() {
      if (_selectedPartIds.contains(partId)) {
        _selectedPartIds.remove(partId);
        if (_selectedPartIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedPartIds.add(partId);
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer ces pièces ?',
      content: '${_selectedPartIds.length} pièce(s) seront supprimées définitivement. Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
      barrierDismissible: false,
    );

    if (!confirmed || !mounted) return;

    var allSucceeded = true;
    for (final partId in _selectedPartIds.toList()) {
      final success = await ref
          .read(partManagementProvider(widget.tentId).notifier)
          .removePart(partId);
      if (!mounted) return;
      if (!success) {
        allSucceeded = false;
        break;
      }
    }

    if (allSucceeded) {
      _exitSelectionMode();
    }
  }

  void _startEditComment(Part part) {
    setState(() {
      _editingCommentPartId = part.id;
    });
  }

  void _cancelEditComment() {
    setState(() {
      _editingCommentPartId = null;
    });
  }

  Future<void> _saveComment(Part part, String value) async {
    final normalized = value.trim().isEmpty ? null : value.trim();
    if (normalized == part.comments?.trim() ||
        (normalized == null && (part.comments?.trim().isEmpty ?? true))) {
      _cancelEditComment();
      return;
    }

    final notifier = ref.read(partUpdateProvider(widget.tentId).notifier);
    final updateState = ref.read(partUpdateProvider(widget.tentId));
    final displayedState = updateState.resolveDisplayedState(part);

    final result = await notifier.updatePartState(
      partId: part.id,
      previousState: displayedState,
      newState: displayedState,
      previousComments: part.comments,
      newComments: normalized,
    );

    if (!mounted) return;
    if (result == PartUpdateResult.success) {
      ref.read(successIndicatorProvider.notifier).fire();
      _cancelEditComment();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managementState = ref.watch(partManagementProvider(widget.tentId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Éléments', style: theme.textTheme.titleMedium),
                ),
                if (!widget.isArchived && !_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Ajouter une pièce',
                    onPressed: _showAddPartDialog,
                  ),
                if (_isSelectionMode) ...[
                  if (_selectedPartIds.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Supprimer les pièces sélectionnées',
                      onPressed: _confirmDeleteSelected,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Annuler la sélection',
                    onPressed: _exitSelectionMode,
                  ),
                ],
              ],
            ),
            if (managementState.removeError != null) ...[
              const SizedBox(height: 8),
              Text(
                managementState.removeError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (widget.parts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun élément associé à cette tente.'),
              )
            else
              ...widget.parts.map((part) => _buildPartRow(part, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartRow(Part part, ThemeData theme) {
    final isSelected = _selectedPartIds.contains(part.id);
    final isEditingThisComment = _editingCommentPartId == part.id;
    final updateState = ref.watch(partUpdateProvider(widget.tentId));
    final displayedState = updateState.resolveDisplayedState(part);
    final inlineError = updateState.errorFor(part.id);
    final isRemoving = ref
        .watch(partManagementProvider(widget.tentId))
        .removingPartIds
        .contains(part.id);

    return InkWell(
      onLongPress: widget.isArchived
          ? null
          : () {
              ref
                  .read(partManagementProvider(widget.tentId).notifier)
                  .clearRemoveError();
              setState(() {
                _isSelectionMode = true;
                _selectedPartIds.add(part.id);
              });
            },
      child: Opacity(
        opacity: isRemoving ? 0.4 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _togglePartSelection(part.id),
                    ),
                  Expanded(
                    child: Text(
                      part.partKindName,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSelectionMode) ...[
                    StateBadge.forPart(context, displayedState),
                    const SizedBox(width: 4),
                  ] else
                    StateSelector<PartState>(
                      values: PartState.values,
                      selectedValue: displayedState,
                      enabled: !widget.isArchived,
                      tooltip: 'Modifier l\'état de ${part.partKindName}',
                      styleFor: partStateBadgeStyle,
                      selectedBadgeBuilder: StateBadge.forPart,
                      onSelected: (newState) async {
                        final notifier = ref.read(
                          partUpdateProvider(widget.tentId).notifier,
                        );
                        final result = await notifier.updatePartState(
                          partId: part.id,
                          previousState: displayedState,
                          newState: newState,
                          previousComments: part.comments,
                          newComments: part.comments,
                        );
                        if (!context.mounted) return;
                        if (result == PartUpdateResult.success) {
                          ref.read(successIndicatorProvider.notifier).fire();
                        }
                      },
                    ),
                ],
              ),
              if (!_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InlineTextEditor(
                    value: part.comments ?? '',
                    isEditing: isEditingThisComment,
                    isEnabled: !widget.isArchived,
                    hintText: 'Ajouter un commentaire...',
                    maxLength: ValidationConstants.tentCommentsMaxLength,
                    minLines: 1,
                    maxLines: 3,
                    dense: true,
                    validator: _validateComments,
                    onStartEditing: () => _startEditComment(part),
                    onCancel: _cancelEditComment,
                    onConfirm: (value) => _saveComment(part, value),
                    readOnlyBuilder: (context, startEditing) {
                      return InkWell(
                        onTap: widget.isArchived ? null : startEditing,
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _displayComment(part.comments),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontStyle: _hasNoComment(part.comments)
                                      ? FontStyle.italic
                                      : null,
                                ),
                              ),
                            ),
                            if (!widget.isArchived) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (inlineError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          inlineError,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(partUpdateProvider(widget.tentId).notifier)
                            .retry(part.id),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayComment(String? comments) {
    final normalized = comments?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Ajouter un commentaire';
    }
    return normalized;
  }

  bool _hasNoComment(String? comments) {
    final normalized = comments?.trim();
    return normalized == null || normalized.isEmpty;
  }

  String? _validateComments(String value) =>
      TentValidators.validateComments(value);

  void _showAddPartDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AddPartSheet(
        tentId: widget.tentId,
        existingPartKindIds: widget.parts.map((p) => p.partKindId).toSet(),
      ),
    );
}
}

class _FieldErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const _FieldErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                label: Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
