import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/part.dart';
import '../../models/tent.dart';
import '../../providers/tent_detail_provider.dart';
import '../../providers/tent_edit_provider.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/constants.dart';
import '../widgets/state_badge.dart';

class TentDetailScreen extends ConsumerWidget {
  final String tentId;

  const TentDetailScreen({super.key, required this.tentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tentAsync = ref.watch(tentDetailProvider(tentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la tente')),
      body: SafeArea(
        child: tentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DetailErrorState(
            message: _toErrorMessage(error),
            onRetry: () => ref.invalidate(tentDetailProvider(tentId)),
          ),
          data: (tent) => _DetailContent(tentId: tentId, tent: tent),
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
    final editState = ref.watch(tentEditProvider);
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
              _HeaderSection(tentId: tentId, tent: tent, editState: editState),
              const SizedBox(height: 16),
              _CommentsSection(
                tentId: tentId,
                tent: tent,
                editState: editState,
              ),
              const SizedBox(height: 16),
              _PartsSection(parts: tent.parts),
              const SizedBox(height: 16),
              _AuditSection(tent: tent),
              if (editState.fieldError != null) ...[
                const SizedBox(height: 12),
                _FieldErrorBanner(
                  message: editState.fieldError!,
                  onDismiss: () =>
                      ref.read(tentEditProvider.notifier).clearError(),
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
            const SizedBox(height: 12),
            Wrap(
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archiver'),
            ),
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

class _EditableNameField extends ConsumerStatefulWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _EditableNameField({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  ConsumerState<_EditableNameField> createState() => _EditableNameFieldState();
}

class _EditableNameFieldState extends ConsumerState<_EditableNameField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tent.name);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_EditableNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editState.editingField != EditableField.name) {
      _controller.text = widget.tent.name;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus &&
        widget.editState.editingField == EditableField.name) {
      _handleCancel();
    }
  }

  bool get _isEditing => widget.editState.editingField == EditableField.name;

  bool get _isSaving =>
      widget.editState.savingField == EditableField.name &&
      widget.editState.editingField == EditableField.name;

  void _handleConfirm() {
    final notifier = ref.read(tentEditProvider.notifier);
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {});
      return;
    }

    if (name.length > ValidationConstants.tentNameMaxLength) {
      setState(() {});
      return;
    }

    _focusNode.unfocus();

    notifier.updateField(
      tentId: widget.tentId,
      name: name,
      size: widget.tent.size,
      overallState: widget.tent.overallState,
      comments: widget.tent.comments,
    );
  }

  void _handleCancel() {
    _controller.text = widget.tent.name;
    ref.read(tentEditProvider.notifier).cancelEditing();
  }

  void _startEditing() {
    _controller.text = widget.tent.name;
    ref
        .read(tentEditProvider.notifier)
        .startEditing(EditableField.name, widget.tent);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isEditing) {
      String? error;
      final trimmed = _controller.text.trim();
      if (trimmed.isEmpty) {
        error = 'Le nom de la tente est requis.';
      } else if (trimmed.length > ValidationConstants.tentNameMaxLength) {
        error =
            'Le nom ne peut pas dépasser ${ValidationConstants.tentNameMaxLength} caractères.';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSaving)
            const LinearProgressIndicator()
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      labelText: 'Nom',
                      hintText: 'Nom de la tente',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleConfirm(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Valider',
                  onPressed: error == null ? _handleConfirm : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Annuler',
                  onPressed: _handleCancel,
                ),
              ],
            ),
          ],
        ],
      );
    }

    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.tent.name,
                style: theme.textTheme.headlineSmall,
              ),
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
  }
}

class _EditableSizeField extends ConsumerStatefulWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _EditableSizeField({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  ConsumerState<_EditableSizeField> createState() => _EditableSizeFieldState();
}

class _EditableSizeFieldState extends ConsumerState<_EditableSizeField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tent.size.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_EditableSizeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editState.editingField != EditableField.size) {
      _controller.text = widget.tent.size.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus &&
        widget.editState.editingField == EditableField.size) {
      _handleCancel();
    }
  }

  bool get _isEditing => widget.editState.editingField == EditableField.size;

  bool get _isSaving =>
      widget.editState.savingField == EditableField.size &&
      widget.editState.editingField == EditableField.size;

  void _handleConfirm() {
    final size = int.tryParse(_controller.text.trim());
    if (size == null || size <= 0 || size > ValidationConstants.tentMaxSize) {
      setState(() {});
      return;
    }

    _focusNode.unfocus();

    ref
        .read(tentEditProvider.notifier)
        .updateField(
          tentId: widget.tentId,
          name: widget.tent.name,
          size: size,
          overallState: widget.tent.overallState,
          comments: widget.tent.comments,
        );
  }

  void _handleCancel() {
    _controller.text = widget.tent.size.toString();
    ref.read(tentEditProvider.notifier).cancelEditing();
  }

  void _startEditing() {
    _controller.text = widget.tent.size.toString();
    ref
        .read(tentEditProvider.notifier)
        .startEditing(EditableField.size, widget.tent);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      String? error;
      final raw = _controller.text.trim();
      final size = int.tryParse(raw);
      if (raw.isEmpty || size == null) {
        error = 'La taille doit être un nombre positif.';
      } else if (size <= 0) {
        error = 'La taille doit être un nombre positif.';
      } else if (size > ValidationConstants.tentMaxSize) {
        error =
            'La taille doit être comprise entre 1 et ${ValidationConstants.tentMaxSize}.';
      }

      return _isSaving
          ? const SizedBox(width: 120, child: LinearProgressIndicator())
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Taille',
                      hintText: 'Nombre de places',
                      errorText: error,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleConfirm(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Valider',
                  visualDensity: VisualDensity.compact,
                  onPressed: error == null ? _handleConfirm : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Annuler',
                  visualDensity: VisualDensity.compact,
                  onPressed: _handleCancel,
                ),
              ],
            );
    }

    return InkWell(
      onTap: _startEditing,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoChip(
              icon: Icons.people_outline,
              label: widget.tent.size == 1
                  ? '1 place'
                  : '${widget.tent.size} places',
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
    final notifier = ref.read(tentEditProvider.notifier);
    final isEditing = editState.editingField == EditableField.overallState;
    final isSaving =
        editState.savingField == EditableField.overallState && isEditing;

    if (isEditing && isSaving) {
      return const SizedBox(
        width: 160,
        height: 32,
        child: LinearProgressIndicator(),
      );
    }

    if (isEditing) {
      return DropdownMenu<TentOverallState>(
        initialSelection: tent.overallState,
        label: const Text('État'),
        dropdownMenuEntries: TentOverallState.values.map((state) {
          final (IconData icon, Color background, Color foreground) =
              _stateColors(context, state);
          return DropdownMenuEntry<TentOverallState>(
            value: state,
            label: state.toFrenchLabel(),
            leadingIcon: Icon(icon, color: foreground, size: 20),
          );
        }).toList(),
        onSelected: (state) {
          if (state == null) return;
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

    return InkWell(
      onTap: () {
        notifier.startEditing(EditableField.overallState, tent);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
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
      ),
    );
  }

  (IconData, Color, Color) _stateColors(
    BuildContext context,
    TentOverallState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (state) {
      TentOverallState.good => (
        Icons.check_circle_outline,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      TentOverallState.needsRepair => (
        Icons.build_circle_outlined,
        Colors.orange.shade100,
        Colors.orange.shade900,
      ),
      TentOverallState.unusable => (
        Icons.cancel_outlined,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _CommentsSection({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tent.comments ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editState.editingField != EditableField.comments) {
      _controller.text = widget.tent.comments ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus &&
        widget.editState.editingField == EditableField.comments) {
      _handleCancel();
    }
  }

  bool get _isEditing =>
      widget.editState.editingField == EditableField.comments;

  bool get _isSaving =>
      widget.editState.savingField == EditableField.comments &&
      widget.editState.editingField == EditableField.comments;

  void _handleConfirm() {
    final trimmed = _controller.text.trim();
    if (trimmed.length > ValidationConstants.tentCommentsMaxLength) {
      setState(() {});
      return;
    }

    _focusNode.unfocus();

    ref
        .read(tentEditProvider.notifier)
        .updateField(
          tentId: widget.tentId,
          name: widget.tent.name,
          size: widget.tent.size,
          overallState: widget.tent.overallState,
          comments: trimmed.isEmpty ? null : trimmed,
        );
  }

  void _handleCancel() {
    _controller.text = widget.tent.comments ?? '';
    ref.read(tentEditProvider.notifier).cancelEditing();
  }

  void _startEditing() {
    _controller.text = widget.tent.comments ?? '';
    ref
        .read(tentEditProvider.notifier)
        .startEditing(EditableField.comments, widget.tent);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final length = _isEditing ? _controller.text.length : 0;

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
                if (_isEditing && !_isSaving)
                  Text(
                    '$length/${ValidationConstants.tentCommentsMaxLength}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: length > ValidationConstants.tentCommentsMaxLength
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isEditing) ...[
              if (_isSaving)
                const LinearProgressIndicator()
              else ...[
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLength: ValidationConstants.tentCommentsMaxLength,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter un commentaire...',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleConfirm(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (_controller.text.length <=
                            ValidationConstants.tentCommentsMaxLength) {
                          _handleConfirm();
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                    ),
                  ],
                ),
              ],
            ] else ...[
              InkWell(
                onTap: _startEditing,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_displayText(widget.tent.comments))),
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
}

class _PartsSection extends StatelessWidget {
  final List<Part> parts;

  const _PartsSection({required this.parts});

  @override
  Widget build(BuildContext context) {
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
              ...parts.map((part) => _PartTile(part: part)),
          ],
        ),
      ),
    );
  }
}

class _PartTile extends StatelessWidget {
  final Part part;

  const _PartTile({required this.part});

  @override
  Widget build(BuildContext context) {
    final comments = part.comments?.trim();
    final displayComments = comments == null || comments.isEmpty
        ? 'Aucun commentaire'
        : comments;

    return Semantics(
      button: true,
      label: '${part.partKindName}, ${part.state.toFrenchLabel()}',
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(part.partKindName),
        subtitle: Text(part.state.toFrenchLabel()),
        trailing: StateBadge.forPart(context, part.state),
        children: [
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
  final VoidCallback onDismiss;

  const _FieldErrorBanner({required this.message, required this.onDismiss});

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

class _DetailErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
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
