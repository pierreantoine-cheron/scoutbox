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

class _InlineEditText extends StatefulWidget {
  final String value;
  final bool isEditing;
  final bool isSaving;
  final bool isEnabled;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final double? editorWidth;
  final bool dense;
  final String? Function(String value) validator;
  final void Function(String value) onConfirm;
  final VoidCallback onStartEditing;
  final VoidCallback onCancel;
  final Widget Function(BuildContext context, VoidCallback startEditing)
  readOnlyBuilder;

  const _InlineEditText({
    required this.value,
    required this.isEditing,
    required this.isSaving,
    required this.isEnabled,
    required this.validator,
    required this.onConfirm,
    required this.onStartEditing,
    required this.onCancel,
    required this.readOnlyBuilder,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.editorWidth,
    this.dense = false,
  });

  @override
  State<_InlineEditText> createState() => _InlineEditTextState();
}

class _InlineEditTextState extends State<_InlineEditText> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_InlineEditText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.value;
    widget.onStartEditing();
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    _controller.text = widget.value;
    widget.onCancel();
  }

  void _confirm() {
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() {});
      return;
    }

    widget.onConfirm(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return widget.readOnlyBuilder(
        context,
        widget.isEnabled ? _startEditing : () {},
      );
    }

    if (widget.isSaving) {
      return widget.editorWidth == null
          ? const LinearProgressIndicator()
          : SizedBox(
              width: widget.editorWidth,
              child: const LinearProgressIndicator(),
            );
    }

    final error = widget.validator(_controller.text);
    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: error,
        border: const OutlineInputBorder(),
        isDense: widget.dense,
      ),
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _confirm(),
    );

    final field = widget.editorWidth == null
        ? Expanded(child: textField)
        : SizedBox(width: widget.editorWidth, child: textField);

    return Row(
      mainAxisSize: widget.editorWidth == null
          ? MainAxisSize.max
          : MainAxisSize.min,
      children: [
        field,
        SizedBox(width: widget.dense ? 0 : 8),
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Valider',
          visualDensity: widget.dense ? VisualDensity.compact : null,
          onPressed: error == null ? _confirm : null,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Annuler',
          visualDensity: widget.dense ? VisualDensity.compact : null,
          onPressed: _cancelEditing,
        ),
      ],
    );
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
    return _InlineEditText(
      value: tent.name,
      isEditing: editState.editingField == EditableField.name,
      isSaving:
          editState.savingField == EditableField.name &&
          editState.editingField == EditableField.name,
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
    return _InlineEditText(
      value: tent.size.toString(),
      isEditing: editState.editingField == EditableField.size,
      isSaving:
          editState.savingField == EditableField.size &&
          editState.editingField == EditableField.size,
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
    final isSaving = editState.savingField == EditableField.overallState;

    if (isSaving) {
      return const SizedBox(
        width: 160,
        height: 32,
        child: LinearProgressIndicator(),
      );
    }

    return PopupMenuButton<TentOverallState>(
      tooltip: '',
      padding: EdgeInsets.zero,
      splashRadius: 1,
      offset: const Offset(0, 40),
      onSelected: (state) {
        if (state == tent.overallState) return;
        notifier.updateField(
          tentId: tentId,
          name: tent.name,
          size: tent.size,
          overallState: state,
          comments: tent.comments,
        );
      },
      itemBuilder: (context) {
        return TentOverallState.values.map((state) {
          final style = tentStateBadgeStyle(context, state);
          final isCurrent = state == tent.overallState;
          return PopupMenuItem<TentOverallState>(
            value: state,
            enabled: !isCurrent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 16, color: style.foreground),
                      const SizedBox(width: 6),
                      Text(
                        style.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: style.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StateBadge.forTent(context, tent.overallState),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: Theme.of(context).colorScheme.outline,
          ),
        ],
      ),
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
    final isSaving =
        editState.savingField == EditableField.comments && isEditing;
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
            _InlineEditText(
              value: tent.comments ?? '',
              isEditing: isEditing,
              isSaving: isSaving,
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

class _PartsSection extends ConsumerWidget {
  final String tentId;
  final List<Part> parts;
  final bool isArchived;

  const _PartsSection({
    required this.tentId,
    required this.parts,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Éléments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (parts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun élément associé à cette tente.'),
              )
            else
              ...parts.map(
                (part) => _PartTile(
                  tentId: tentId,
                  part: part,
                  isArchived: isArchived,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PartTile extends ConsumerWidget {
  final String tentId;
  final Part part;
  final bool isArchived;

  const _PartTile({
    required this.tentId,
    required this.part,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = part.comments?.trim();
    final displayComments = comments == null || comments.isEmpty
        ? 'Aucun commentaire'
        : comments;
    final notifier = ref.read(partUpdateProvider(tentId).notifier);
    final displayedState = notifier.resolveDisplayedState(part);
    final isSaving = notifier.isSaving(part.id);
    final inlineError = notifier.errorFor(part.id);

    return Semantics(
      button: true,
      label: '${part.partKindName}, ${displayedState.toFrenchLabel()}',
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(part.partKindName),
        subtitle: Text(displayedState.toFrenchLabel()),
        trailing: PopupMenuButton<PartState>(
          enabled: !isArchived && !isSaving,
          tooltip: 'Modifier l\'état de ${part.partKindName}',
          onSelected: (newState) async {
            await notifier.updatePartState(
              partId: part.id,
              previousState: displayedState,
              newState: newState,
            );
            if (!context.mounted) {
              return;
            }
            if (notifier.errorFor(part.id) == null) {
              ref.read(successIndicatorProvider.notifier).fire();
            }
          },
          itemBuilder: (context) {
            return PartState.values
                .map(
                  (state) => CheckedPopupMenuItem<PartState>(
                    value: state,
                    checked: state == displayedState,
                    child: Row(
                      children: [
                        Icon(partStateBadgeStyle(context, state).icon),
                        const SizedBox(width: 8),
                        Text(state.toFrenchLabel()),
                      ],
                    ),
                  ),
                )
                .toList();
          },
          child: Opacity(
            opacity: isArchived ? 0.55 : 1,
            child: StateBadge.forPart(context, displayedState),
          ),
        ),
        children: [
          if (isSaving) const LinearProgressIndicator(),
          if (inlineError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(inlineError)),
                  TextButton(
                    onPressed: () => notifier.retry(part.id),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Commentaires: $displayComments'),
          ),
        ],
      ),
    );
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
