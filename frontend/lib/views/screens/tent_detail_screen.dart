import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/constants.dart';
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
    final displayedTent = editState.baseTent?.id == tentId
        ? editState.baseTent!
        : tent;
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
              _AuditSection(tent: displayedTent),
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

  String? _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Le nom de la tente est requis.';
    if (trimmed.length > ValidationConstants.tentNameMaxLength) {
      return 'Le nom ne peut pas dépasser ${ValidationConstants.tentNameMaxLength} caractères.';
    }
    return null;
  }
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

  String? _validateSize(String value) {
    final raw = value.trim();
    final size = int.tryParse(raw);
    if (raw.isEmpty || size == null || size <= 0) {
      return 'La taille doit être un nombre positif.';
    }
    if (size > ValidationConstants.tentMaxSize) {
      return 'La taille doit être comprise entre 1 et ${ValidationConstants.tentMaxSize}.';
    }
    return null;
  }
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

  String? _validateComments(String value) {
    if (value.trim().length > ValidationConstants.tentCommentsMaxLength) {
      return 'Le commentaire ne peut pas dépasser ${ValidationConstants.tentCommentsMaxLength} caractères.';
    }
    return null;
  }
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

  String? _validateComments(String value) {
    if (value.trim().length > ValidationConstants.tentCommentsMaxLength) {
      return 'Le commentaire ne peut pas dépasser ${ValidationConstants.tentCommentsMaxLength} caractères.';
    }
    return null;
  }

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

class _AuditSection extends StatelessWidget {
  final Tent tent;

  const _AuditSection({required this.tent});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatAudit('Créée le', tent.createdAt, formatter)),
            const SizedBox(height: 6),
            Text(
              _formatAudit(
                'Dernière modification le',
                tent.updatedAt,
                formatter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAudit(String label, DateTime? value, DateFormat formatter) {
    if (value == null) {
      return '$label -';
    }

    return '$label ${formatter.format(value.toLocal())}';
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
