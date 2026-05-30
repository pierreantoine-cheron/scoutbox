import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/constants.dart';
import '../../utils/tent_validators.dart';
import '../widgets/widgets.dart';

class TentDetailScreen extends ConsumerStatefulWidget {
  final String tentId;

  const TentDetailScreen({super.key, required this.tentId});

  @override
  ConsumerState<TentDetailScreen> createState() => _TentDetailScreenState();
}

class _TentDetailScreenState extends ConsumerState<TentDetailScreen>
    with RouteAware {
  DateTime? _lastSeenSaveTime;
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver ??= ref.read(routeObserverProvider);
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        _routeObserver!.unsubscribe(this);
      }
      _routeObserver!.subscribe(this, route);
      _subscribedRoute = route;
    }
    _scheduleConfigUpdate();
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    _subscribedRoute = null;
    super.dispose();
  }

  @override
  void didPush() {
    _scheduleConfigUpdate();
  }

  void _scheduleConfigUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setAppBarConfig();
    });
  }

  void _setAppBarConfig() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    ref
        .read(appBarConfigProvider.notifier)
        .set(
          const AppBarConfig(
            screenId: 'tent_detail',
            title: Text('Détail de la tente'),
            showBackButton: true,
          ),
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
              _HistorySection(tentId: tentId),
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
                      label: _shapeLabel(tent.tentShapeName),
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

  String _shapeLabel(String? value) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver la tente'),
        content: const Text(
          'Archiver cette tente ? Elle n\'apparaîtra plus dans la liste mais restera dans l\'historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ces pièces ?'),
        content: Text(
          '${_selectedPartIds.length} pièce(s) seront supprimées définitivement. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

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
      builder: (sheetContext) => _AddPartSheet(
        tentId: widget.tentId,
        existingPartKindIds: widget.parts.map((p) => p.partKindId).toSet(),
      ),
    );
  }
}

class _AddPartSheet extends ConsumerStatefulWidget {
  final String tentId;
  final Set<String> existingPartKindIds;

  const _AddPartSheet({
    required this.tentId,
    required this.existingPartKindIds,
  });

  @override
  ConsumerState<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends ConsumerState<_AddPartSheet> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(partManagementProvider(widget.tentId).notifier).loadPartKinds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partManagementProvider(widget.tentId));
    final theme = Theme.of(context);
    final canSubmit =
        _selectedIds.isNotEmpty &&
        !state.isAdding &&
        !_hasEmptySearchResults(state);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ajouter une pièce', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (state.isLoadingPartKinds)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Chargement des pièces…'),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.partKindsError != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    state.partKindsError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
            else
              Expanded(child: _buildPartKindList(state, theme)),
            if (state.addError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.addError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSubmit ? _onConfirm : null,
                    child: state.isAdding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasEmptySearchResults(PartManagementState state) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return false;
    return !state.partKinds.any((pk) => pk.name.toLowerCase().contains(query));
  }

  Widget _buildPartKindList(PartManagementState state, ThemeData theme) {
    final query = _searchController.text.trim().toLowerCase();
    final partKinds = state.partKinds.where((pk) {
      if (query.isEmpty) return true;
      return pk.name.toLowerCase().contains(query);
    }).toList();

    final existingIds = widget.existingPartKindIds;

    if (partKinds.isEmpty && query.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucun type de pièce trouvé',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final existingPartKinds = partKinds
        .where((pk) => existingIds.contains(pk.id))
        .toList();
    final availablePartKinds = partKinds
        .where((pk) => !existingIds.contains(pk.id))
        .toList();

    final allPresent = availablePartKinds.isEmpty && partKinds.isNotEmpty;

    return ListView(
      children: [
        if (allPresent)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Toutes les pièces sont déjà présentes sur cette tente.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...availablePartKinds.map(
          (pk) => CheckboxListTile(
            value: _selectedIds.contains(pk.id),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedIds.add(pk.id);
                } else {
                  _selectedIds.remove(pk.id);
                }
              });
            },
            title: Text(pk.name),
            subtitle: Text('Ordre : ${pk.displayOrder}'),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ),
        if (existingPartKinds.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Déjà présente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ...existingPartKinds.map(
            (pk) => CheckboxListTile(
              value: false,
              onChanged: null,
              title: Text(
                pk.name,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              subtitle: Text(
                'Ordre : ${pk.displayOrder}',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onConfirm() async {
    final success = await ref
        .read(partManagementProvider(widget.tentId).notifier)
        .addParts(_selectedIds.toList());
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _HistorySection extends ConsumerStatefulWidget {
  final String tentId;

  const _HistorySection({required this.tentId});

  @override
  ConsumerState<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<_HistorySection> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _categories = <_FilterOption>[
    _FilterOption(label: 'Tout', value: null),
    _FilterOption(label: 'Tente', value: 'tent_info'),
    _FilterOption(label: 'États', value: 'part_state'),
    _FilterOption(label: 'Pièces', value: 'part_management'),
    _FilterOption(label: 'Archive', value: 'archive'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      tentHistoryProvider(widget.tentId, category: _selectedCategory),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat.value == _selectedCategory;
                  return FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? cat.value : null;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher dans l\'historique',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Chargement de l\'historique...'),
                    ],
                  ),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _toHistoryErrorMessage(error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(
                        tentHistoryProvider(
                          widget.tentId,
                          category: _selectedCategory,
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery;
                  return _historySummary(item).toLowerCase().contains(query) ||
                      item.actorDisplayName.toLowerCase().contains(query) ||
                      item.action.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Aucun historique à afficher.')),
                  );
                }

                final grouped = _groupByDate(filtered);
                return _HistoryList(grouped: grouped);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _historySummary(TentHistoryItem item) {
    return _buildHistorySummary(item);
  }

  String _toHistoryErrorMessage(Object error) {
    if (error is TentRepositoryException) {
      return error.message;
    }
    return 'Impossible de charger l\'historique.';
  }

  Map<String, List<TentHistoryItem>> _groupByDate(List<TentHistoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayFormatter = DateFormat('d MMMM yyyy', 'fr');

    final grouped = <String, List<TentHistoryItem>>{};
    for (final item in items) {
      final localDate = item.occurredAt.toLocal();
      final itemDay = DateTime(localDate.year, localDate.month, localDate.day);
      String label;
      if (itemDay == today) {
        label = "Aujourd'hui";
      } else if (itemDay == yesterday) {
        label = 'Hier';
      } else {
        label = dayFormatter.format(localDate);
      }
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }
}

class _FilterOption {
  final String label;
  final String? value;
  const _FilterOption({required this.label, this.value});
}

class _HistoryList extends StatelessWidget {
  final Map<String, List<TentHistoryItem>> grouped;

  const _HistoryList({required this.grouped});

  @override
  Widget build(BuildContext context) {
    final entries = grouped.entries.toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...entry.value.map((item) => _HistoryEntry(item: item)),
          ],
        );
      },
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  final TentHistoryItem item;

  const _HistoryEntry({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = _actionIcon(item.action);
    final time = DateFormat('HH:mm', 'fr').format(item.occurredAt.toLocal());
    final summary = _buildHistorySummary(item);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(icon, size: 20, color: colorScheme.primary),
        title: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
        subtitle: Text(
          '$time • ${item.actorDisplayName}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        enabled: item.details.isNotEmpty,
        children: item.details.map((detail) {
          return _buildDetail(context, detail);
        }).toList(),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, TentHistoryDetail detail) {
    final colorScheme = Theme.of(context).colorScheme;

    if (detail.valueType == 'state' || detail.valueType == 'old_new') {
      final hasOldNew = detail.oldValue != null && detail.newValue != null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Text(
              '${detail.label}:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (hasOldNew) ...[
              _buildStateValue(context, detail.oldValue),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14),
              ),
              _buildStateValue(context, detail.newValue),
            ] else
              Text(
                detail.value ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
    }

    if (detail.valueType == 'flag') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          detail.value ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '${detail.label}: ${detail.value ?? detail.newValue ?? detail.oldValue ?? ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildStateValue(BuildContext context, String? value) {
    if (value == null) return const Text('-');

    final parsedPartState = PartState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;

    if (parsedPartState != null) {
      return StateBadge.forPart(context, parsedPartState);
    }

    final parsedTentState = TentOverallState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;

    if (parsedTentState != null) {
      return StateBadge.forTent(context, parsedTentState);
    }

    return Text(value);
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'tent_created':
        return Icons.add_circle_outline;
      case 'tent_updated':
        return Icons.edit_outlined;
      case 'tent_archived':
        return Icons.archive_outlined;
      case 'part_state_changed':
        return Icons.swap_horiz;
      case 'part_comments_changed':
        return Icons.comment_outlined;
      case 'part_added':
        return Icons.add_box_outlined;
      case 'part_deleted':
        return Icons.remove_circle_outline;
      default:
        return Icons.info_outline;
    }
  }
}

String _buildHistorySummary(TentHistoryItem item) {
  final localDate = item.occurredAt.toLocal();
  final date = DateFormat('dd/MM/yyyy', 'fr').format(localDate);
  final time = DateFormat('HH:mm', 'fr').format(localDate);
  final suffix = 'le $date à $time par ${item.actorDisplayName}';
  final subject = item.subjectName ?? 'Pièce inconnue';

  switch (item.action) {
    case 'tent_created':
      return 'Tente créée $suffix';
    case 'tent_updated':
      return 'Informations mises à jour $suffix';
    case 'tent_archived':
      return 'Tente archivée $suffix';
    case 'part_state_changed':
      final stateDetail = item.details
          .where((d) => d.valueType == 'state')
          .firstOrNull;
      final oldState = _historyStateLabel(stateDetail?.oldValue);
      final newState = _historyStateLabel(stateDetail?.newValue);
      return 'État de $subject changé de $oldState à $newState $suffix';
    case 'part_comments_changed':
      return 'Commentaire de $subject modifié $suffix';
    case 'part_added':
      return 'Pièce ajoutée : $subject $suffix';
    case 'part_deleted':
      return 'Pièce supprimée : $subject $suffix';
    default:
      return 'Action ${item.action} $suffix';
  }
}

String _historyStateLabel(String? value) {
  if (value == null || value.isEmpty) return '?';

  final partState = PartState.values
      .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
      .firstOrNull;
  if (partState != null) return partState.toFrenchLabel();

  final tentState = TentOverallState.values
      .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
      .firstOrNull;
  if (tentState != null) return tentState.toFrenchLabel();

  return value;
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
