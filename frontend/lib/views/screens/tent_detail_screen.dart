import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_sheet.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
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

    final tentAsync = ref.read(tentDetailProvider(widget.tentId));
    final tent = tentAsync.asData?.value;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    return AppBarConfig(
      screenId: 'tent_detail',
      title: const Text('Détail tente'),
      showBackButton: true,
      actions: [
        if (tent != null && !tent.isArchived)
          _ArchiveAppBarButton(
            tentId: widget.tentId,
            showLabel: isDesktop,
          ),
      ],
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

class _ArchiveAppBarButton extends ConsumerStatefulWidget {
  final String tentId;
  final bool showLabel;

  const _ArchiveAppBarButton({required this.tentId, required this.showLabel});

  @override
  ConsumerState<_ArchiveAppBarButton> createState() =>
      _ArchiveAppBarButtonState();
}

class _ArchiveAppBarButtonState extends ConsumerState<_ArchiveAppBarButton> {
  bool _isArchiving = false;

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    if (_isArchiving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.showLabel) {
      return TextButton.icon(
        onPressed: _onArchivePressed,
        icon: const Icon(Icons.archive_outlined, size: 18),
        label: const Text('Archiver'),
        style: TextButton.styleFrom(
          foregroundColor: semanticColors.stateUnusable,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.archive_outlined),
      tooltip: 'Archiver la tente',
      onPressed: _onArchivePressed,
      style: IconButton.styleFrom(
        foregroundColor: semanticColors.stateUnusable,
      ),
    );
  }

  Future<void> _onArchivePressed() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Archiver la tente',
      content:
          'Archiver cette tente ? Elle n\'apparaîtra plus dans la liste mais restera dans l\'historique.',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isArchiving = true);

    try {
      final archivedTent = await ref
          .read(tentRepositoryProvider)
          .archiveTent(widget.tentId);
      invalidateTentHistory(ref, widget.tentId);
      ref.read(tentListProvider.notifier).hideTent(archivedTent.id);
      ref.read(successIndicatorProvider.notifier).fire();

      if (mounted) Navigator.of(context).maybePop();
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
      if (mounted) setState(() => _isArchiving = false);
    }
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
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 16,
            isWide ? 24 : 16,
            isWide ? 24 : 16,
            48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IdentityBlock(
                tentId: tentId,
                tent: displayedTent,
                editState: editState,
              ),
              const Divider(),
              _TagsBlock(tentId: tentId, tent: displayedTent),
              const Divider(),
              _PartsBlock(
                tentId: tentId,
                parts: displayedTent.parts,
                isArchived: displayedTent.isArchived,
              ),
              const Divider(),
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

class _IdentityBlock extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final TentEditState editState;

  const _IdentityBlock({
    required this.tentId,
    required this.tent,
    required this.editState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tent.isArchived)
            _ArchiveBanner(
              color: semanticColors.stateUnusable,
              background: semanticColors.stateUnusableBackground,
            ),
          _TentNameHero(
            tentId: tentId,
            tent: tent,
            isArchived: tent.isArchived,
          ),
          const SizedBox(height: 10),
          _InfoChipsRow(
            tentId: tentId,
            tent: tent,
            isArchived: tent.isArchived,
          ),
          const SizedBox(height: 14),
          _CommentsPreview(
            tentId: tentId,
            tent: tent,
            isArchived: tent.isArchived,
          ),
        ],
      ),
    );
  }
}

class _ArchiveBanner extends StatelessWidget {
  final Color color;
  final Color background;

  const _ArchiveBanner({required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.archive_outlined, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              'Cette tente est archivée.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TentNameHero extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final bool isArchived;

  const _TentNameHero({
    required this.tentId,
    required this.tent,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isArchived ? null : () => _showEditNameSheet(context, ref),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          tent.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.33,
          ),
        ),
      ),
    );
  }

  Future<void> _showEditNameSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController(text: tent.name);
    final focusNode = FocusNode();
    final formKey = GlobalKey<FormState>();

    final result = await showResponsiveSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return _EditSheetContent(
          title: 'Modifier le nom',
          controller: controller,
          focusNode: focusNode,
          formKey: formKey,
          maxLength: ValidationConstants.tentNameMaxLength,
          label: 'Nom de la tente',
          validator: (value) {
            final trimmed = (value ?? '').trim();
            if (trimmed.isEmpty) return 'Le nom est requis';
            if (trimmed.length > ValidationConstants.tentNameMaxLength) {
              return '${ValidationConstants.tentNameMaxLength} caractères maximum';
            }
            return null;
          },
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onSave: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.of(sheetContext).pop(true);
          },
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != tent.name) {
        ref.read(tentEditProvider(tentId).notifier).updateField(
              tentId: tentId,
              name: newName,
              size: tent.size,
              overallState: tent.overallState,
              comments: tent.comments,
            );
      }
    }
  }
}

class _InfoChipsRow extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final bool isArchived;

  const _InfoChipsRow({
    required this.tentId,
    required this.tent,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = isArchived ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: isArchived,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatePill(tentId: tentId, tent: tent),
            _SizeChip(tentId: tentId, tent: tent),
            _ModelChip(tentId: tentId, tent: tent),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends ConsumerWidget {
  final String tentId;
  final Tent tent;

  const _StatePill({required this.tentId, required this.tent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = tentStateBadgeStyle(context, tent.overallState);

    return InkWell(
      onTap: () => _showEditStateSheet(context, ref),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 12, color: style.foreground),
            const SizedBox(width: 6),
            Text(
              style.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditStateSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showResponsiveSheet<TentOverallState>(
      context: context,
      builder: (sheetContext) {
        return _StatePickerSheet<TentOverallState>(
          title: 'Modifier l\'état',
          values: TentOverallState.values,
          currentValue: tent.overallState,
          styleFor: (context, state) => tentStateBadgeStyle(context, state),
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && context.mounted && result != tent.overallState) {
      ref.read(tentEditProvider(tentId).notifier).updateField(
            tentId: tentId,
            name: tent.name,
            size: tent.size,
            overallState: result,
            comments: tent.comments,
          );
    }
  }
}

class _SizeChip extends ConsumerWidget {
  final String tentId;
  final Tent tent;

  const _SizeChip({required this.tentId, required this.tent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = tent.size == 1 ? '1 place' : '${tent.size} places';

    return InkWell(
      onTap: () => _showEditSizeSheet(context, ref),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSizeSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController(text: tent.size.toString());
    final focusNode = FocusNode();
    final formKey = GlobalKey<FormState>();

    final result = await showResponsiveSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return _EditSheetContent(
          title: 'Modifier la taille',
          controller: controller,
          focusNode: focusNode,
          formKey: formKey,
          keyboardType: TextInputType.number,
          label: 'Nombre de places',
          validator: (value) {
            final parsed = int.tryParse((value ?? '').trim());
            if (parsed == null || parsed < 1 || parsed > ValidationConstants.tentMaxSize) {
              return 'Entre 1 et ${ValidationConstants.tentMaxSize}';
            }
            return null;
          },
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onSave: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.of(sheetContext).pop(true);
          },
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newSize = int.tryParse(controller.text.trim());
      if (newSize != null && newSize != tent.size) {
        ref.read(tentEditProvider(tentId).notifier).updateField(
              tentId: tentId,
              name: tent.name,
              size: newSize,
              overallState: tent.overallState,
              comments: tent.comments,
            );
      }
    }
  }
}

class _ModelChip extends ConsumerWidget {
  final String tentId;
  final Tent tent;

  const _ModelChip({required this.tentId, required this.tent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modelName = (tent.tentModelName?.trim().isNotEmpty ?? false)
        ? tent.tentModelName!
        : 'Type inconnu';

    return InkWell(
      onTap: () => _showEditModelSheet(context, ref),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain_outlined, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Text(
              modelName,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditModelSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final modelsAsync = ref.read(tentModelsProvider);
    final models = modelsAsync.asData?.value ?? const [];

    if (models.isEmpty) return;

    final result = await showResponsiveSheet<String>(
      context: context,
      builder: (sheetContext) {
        return _ModelPickerSheet(
          title: 'Modifier le modèle',
          models: models,
          currentModelId: tent.tentModelId,
          onSelected: (modelId) => Navigator.of(sheetContext).pop(modelId),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && context.mounted && result != tent.tentModelId) {
      ref.read(tentEditProvider(tentId).notifier).updateModel(
            tentId: tentId,
            tentModelId: result,
            name: tent.name,
            size: tent.size,
            overallState: tent.overallState,
            comments: tent.comments,
          );
    }
  }
}

class _CommentsPreview extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final bool isArchived;

  const _CommentsPreview({
    required this.tentId,
    required this.tent,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isArchived ? null : () => _showEditCommentsSheet(context, ref),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _displayComments(theme),
            ),
            if (!isArchived)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _displayComments(ThemeData theme) {
    final normalized = tent.comments?.trim();
    if (normalized == null || normalized.isEmpty) {
      return Text(
        'Ajouter un commentaire...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(
      normalized,
      style: theme.textTheme.bodyMedium,
    );
  }

  Future<void> _showEditCommentsSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController(text: tent.comments ?? '');
    final focusNode = FocusNode();

    final result = await showResponsiveSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _EditSheetContent(
          title: 'Modifier le commentaire',
          controller: controller,
          focusNode: focusNode,
          maxLength: ValidationConstants.tentCommentsMaxLength,
          label: 'Commentaire',
          maxLines: 4,
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onSave: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newComments = controller.text.trim();
      if (newComments != (tent.comments?.trim() ?? '')) {
        ref.read(tentEditProvider(tentId).notifier).updateField(
              tentId: tentId,
              name: tent.name,
              size: tent.size,
              overallState: tent.overallState,
              comments: newComments.isEmpty ? null : newComments,
            );
      }
    }
  }
}

class _TagsBlock extends ConsumerWidget {
  final String tentId;
  final Tent tent;

  const _TagsBlock({required this.tentId, required this.tent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  label: 'Étiquettes',
                ),
              ),
              if (!tent.isArchived)
                _ModifierButton(
                  label: 'Modifier',
                  onPressed: () => _showEditTagsSheet(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (tent.tags.isEmpty)
            Text(
              'Aucune étiquette',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tent.tags
                  .map(
                    (tag) => _DetailTagChip(
                      name: tag.name,
                      color: TagPalette.colorFromHex(tag.color),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditTagsSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showResponsiveSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => TagAssignmentSheet(
        tentId: tentId,
        assignedTagIds: tent.tags.map((tag) => tag.id).toSet(),
      ),
    );
    ref.invalidate(tentDetailProvider(tentId));
  }
}

class _DetailTagChip extends StatelessWidget {
  final String name;
  final Color color;

  const _DetailTagChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = TagPalette.textColorFor(color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _PartsBlock extends ConsumerStatefulWidget {
  final String tentId;
  final List<Part> parts;
  final bool isArchived;

  const _PartsBlock({
    required this.tentId,
    required this.parts,
    required this.isArchived,
  });

  @override
  ConsumerState<_PartsBlock> createState() => _PartsBlockState();
}

class _PartsBlockState extends ConsumerState<_PartsBlock> {
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
      content:
          '${_selectedPartIds.length} pièce(s) seront supprimées définitivement. Cette action est irréversible.',
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

    if (allSucceeded) _exitSelectionMode();
  }

  void _startEditComment(Part part) {
    setState(() => _editingCommentPartId = part.id);
  }

  void _cancelEditComment() {
    setState(() => _editingCommentPartId = null);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managementState = ref.watch(partManagementProvider(widget.tentId));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  label: 'Éléments (${widget.parts.length})',
                ),
              ),
              if (!widget.isArchived && !_isSelectionMode)
                _ModifierButton(
                  label: 'Modifier',
                  onPressed: _showEditPartsSheet,
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
          const SizedBox(height: 12),
          if (widget.parts.isEmpty)
            Text(
              'Aucun élément',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...widget.parts.map((part) => _buildPartRow(part, theme)),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 5),
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
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(
                    child: Text(
                      part.partKindName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSelectionMode) ...[
                    StateBadge.forPart(context, displayedState),
                    const SizedBox(width: 4),
                  ] else
                    _PartStateBadge(
                      tentId: widget.tentId,
                      part: part,
                      displayedState: displayedState,
                      isArchived: widget.isArchived,
                    ),
                ],
              ),
              if (!_isSelectionMode)
                _PartCommentRow(
                  part: part,
                  isEditing: isEditingThisComment,
                  isArchived: widget.isArchived,
                  onStartEdit: () => _startEditComment(part),
                  onCancelEdit: _cancelEditComment,
                  onSave: (value) => _saveComment(part, value),
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

  void _showEditPartsSheet() {
    showResponsiveSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AddPartSheet(
        tentId: widget.tentId,
        existingPartKindIds:
            widget.parts.map((p) => p.partKindId).toSet(),
      ),
    );
  }
}

class _PartStateBadge extends ConsumerWidget {
  final String tentId;
  final Part part;
  final PartState displayedState;
  final bool isArchived;

  const _PartStateBadge({
    required this.tentId,
    required this.part,
    required this.displayedState,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = partStateBadgeStyle(context, displayedState);

    return InkWell(
      onTap: isArchived
          ? null
          : () => _showEditPartStateSheet(context, ref),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 12, color: style.foreground),
            const SizedBox(width: 5),
            Text(
              style.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPartStateSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showResponsiveSheet<PartState>(
      context: context,
      builder: (sheetContext) {
        return _StatePickerSheet<PartState>(
          title: 'Modifier l\'état de l\'élément',
          values: PartState.values,
          currentValue: displayedState,
          styleFor: (context, state) => partStateBadgeStyle(context, state),
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && context.mounted && result != displayedState) {
      final notifier = ref.read(partUpdateProvider(tentId).notifier);
      final updateResult = await notifier.updatePartState(
        partId: part.id,
        previousState: displayedState,
        newState: result,
        previousComments: part.comments,
        newComments: part.comments,
      );
      if (context.mounted && updateResult == PartUpdateResult.success) {
        ref.read(successIndicatorProvider.notifier).fire();
      }
    }
  }
}

class _PartCommentRow extends StatelessWidget {
  final Part part;
  final bool isEditing;
  final bool isArchived;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final void Function(String) onSave;

  const _PartCommentRow({
    required this.part,
    required this.isEditing,
    required this.isArchived,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isEditing) {
      return InlineTextEditor(
        value: part.comments ?? '',
        isEditing: true,
        isEnabled: true,
        hintText: 'Ajouter un commentaire...',
        maxLength: ValidationConstants.tentCommentsMaxLength,
        minLines: 1,
        maxLines: 3,
        dense: true,
        validator: (_) => null,
        onStartEditing: () {},
        onCancel: onCancelEdit,
        onConfirm: onSave,
        readOnlyBuilder: (_, _) => const SizedBox.shrink(),
      );
    }

    return InkWell(
      onTap: isArchived ? null : onStartEdit,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _displayComment(part.comments),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle:
                      _hasNoComment(part.comments) ? FontStyle.italic : null,
                ),
              ),
            ),
            if (!isArchived) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: theme.colorScheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayComment(String? comments) {
    final normalized = comments?.trim();
    if (normalized == null || normalized.isEmpty) return 'Ajouter un commentaire';
    return normalized;
  }

  bool _hasNoComment(String? comments) {
    final normalized = comments?.trim();
    return normalized == null || normalized.isEmpty;
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
    );
  }
}

class _ModifierButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ModifierButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_outlined, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
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
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semanticColors.stateUnusableBackground,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: semanticColors.stateUnusable.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: semanticColors.stateUnusable,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: semanticColors.stateUnusable),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
          IconButton(
            icon: Icon(
              Icons.close,
              color: semanticColors.stateUnusable,
            ),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _EditSheetContent extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey<FormState>? formKey;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final String? Function(String?)? validator;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditSheetContent({
    super.key,
    required this.title,
    required this.controller,
    required this.focusNode,
    this.formKey,
    required this.label,
    this.keyboardType,
    this.maxLength,
    this.maxLines,
    this.validator,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_EditSheetContent> createState() => _EditSheetContentState();
}

class _EditSheetContentState extends State<_EditSheetContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Form(
              key: widget.formKey,
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: widget.keyboardType,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines ?? 1,
                minLines: widget.maxLines ?? 1,
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: widget.validator ??
                    (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Ce champ est requis';
                      }
                      return null;
                    },
                onFieldSubmitted: (_) => widget.onSave(),
              ),
            ),
          ),
          if (widget.maxLength != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${widget.controller.text.length} / ${widget.maxLength}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }
}

class _StatePickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T currentValue;
  final StateBadgeStyle Function(BuildContext, T) styleFor;
  final void Function(T) onSelected;
  final VoidCallback onCancel;

  const _StatePickerSheet({
    super.key,
    required this.title,
    required this.values,
    required this.currentValue,
    required this.styleFor,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...values.map((value) {
          final style = styleFor(context, value);
          final isCurrent = value == currentValue;

          return InkWell(
            onTap: () => onSelected(value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3)
                    : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(style.icon, size: 20, color: style.foreground),
                  const SizedBox(width: 10),
                  Text(
                    style.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: style.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isCurrent) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModelPickerSheet extends StatelessWidget {
  final String title;
  final List<TentModel> models;
  final String currentModelId;
  final void Function(String) onSelected;
  final VoidCallback onCancel;

  const _ModelPickerSheet({
    super.key,
    required this.title,
    required this.models,
    required this.currentModelId,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...models.map((model) {
          final isCurrent = model.id == currentModelId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: isCurrent ? null : () => onSelected(model.id),
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: isCurrent ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.terrain_outlined,
                      size: 18,
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        model.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
