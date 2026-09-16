import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_theme_context.dart';
import '../../utils/design_constants.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_sheet.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class TentDetailScreen extends ConsumerStatefulWidget {
  final String tentId;
  final VoidCallback onManageTags;

  const TentDetailScreen({super.key, required this.tentId, required this.onManageTags});

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
    final isDesktop = MediaQuery.sizeOf(context).width >= DesignConstants.desktopBreakpoint;

    return AppBarConfig(
      screenId: 'tent_detail',
      title: const Text('Détail tente'),
      showBackButton: true,
      actions: [
        if (tent != null && tent.isArchived)
          _UnarchiveAppBarButton(
            tentId: widget.tentId,
            showLabel: isDesktop,
          )
        else if (tent != null && !tent.isArchived)
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

    ref.listen(tentDetailProvider(widget.tentId), (_, _) {
      dispatchAppBarConfig();
    });

    if (editState.lastSaveTime != null && editState.lastSaveTime != _lastSeenSaveTime) {
      _lastSeenSaveTime = editState.lastSaveTime;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(successIndicatorProvider.notifier).fire();
      });
    }

    return DataScreenScaffold(
      state: tentAsync,
      errorFallbackMessage: 'Impossible de charger le détail de la tente.',
      onRetry: () => ref.invalidate(tentDetailProvider(widget.tentId)),
      builder: (tent) => _DetailContent(
        tentId: widget.tentId,
        tent: tent,
        onManageTags: widget.onManageTags,
      ),
    );
  }
}

class _ArchiveAppBarButton extends ConsumerStatefulWidget {
  final String tentId;
  final bool showLabel;

  const _ArchiveAppBarButton({required this.tentId, required this.showLabel});

  @override
  ConsumerState<_ArchiveAppBarButton> createState() => _ArchiveAppBarButtonState();
}

class _ArchiveAppBarButtonState extends ConsumerState<_ArchiveAppBarButton> {
  bool _isArchiving = false;

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.semanticColors;

    if (_isArchiving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: AppProgressIndicator(),
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
      await ref.read(tentRepositoryProvider).archiveTent(widget.tentId);
      invalidateTentHistory(ref, widget.tentId);
      ref.invalidate(tentListProvider);
      ref.invalidate(tentDetailProvider(widget.tentId));
      ref.read(successIndicatorProvider.notifier).fire();
    } catch (e) {
      if (mounted) {
        final message = e is TentRepositoryException
            ? ErrorLocalizer.localize(e.code, fallback: e.message)
            : 'Impossible d\'archiver la tente. Réessayez.';
        await showErrorDialog(context, message);
      }
    } finally {
      if (mounted) setState(() => _isArchiving = false);
    }
  }
}

class _UnarchiveAppBarButton extends ConsumerStatefulWidget {
  final String tentId;
  final bool showLabel;

  const _UnarchiveAppBarButton({required this.tentId, required this.showLabel});

  @override
  ConsumerState<_UnarchiveAppBarButton> createState() => _UnarchiveAppBarButtonState();
}

class _UnarchiveAppBarButtonState extends ConsumerState<_UnarchiveAppBarButton> {
  bool _isUnarchiving = false;

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.semanticColors;

    if (_isUnarchiving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: AppProgressIndicator(),
        ),
      );
    }

    if (widget.showLabel) {
      return TextButton.icon(
        onPressed: _onUnarchivePressed,
        icon: const Icon(Icons.unarchive_outlined, size: 18),
        label: const Text('Désarchiver'),
        style: TextButton.styleFrom(
          foregroundColor: semanticColors.stateUsable,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.unarchive_outlined),
      tooltip: 'Désarchiver la tente',
      onPressed: _onUnarchivePressed,
      style: IconButton.styleFrom(
        foregroundColor: semanticColors.stateUsable,
      ),
    );
  }

  Future<void> _onUnarchivePressed() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Désarchiver la tente',
      content: 'Désarchiver cette tente ? Elle réapparaîtra dans la liste active.',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isUnarchiving = true);

    try {
      final unarchivedTent = await ref.read(tentRepositoryProvider).unarchiveTent(widget.tentId);
      invalidateTentHistory(ref, widget.tentId);
      ref.read(tentListProvider.notifier).showTent(unarchivedTent);
      ref.invalidate(tentDetailProvider(widget.tentId));
      ref.read(successIndicatorProvider.notifier).fire();
    } catch (e) {
      if (mounted) {
        final message = e is TentRepositoryException
            ? ErrorLocalizer.localize(e.code, fallback: e.message)
            : 'Impossible de désarchiver la tente. Réessayez.';
        await showErrorDialog(context, message);
      }
    } finally {
      if (mounted) setState(() => _isUnarchiving = false);
    }
  }
}

class _DetailContent extends ConsumerWidget {
  final String tentId;
  final Tent tent;
  final VoidCallback onManageTags;

  const _DetailContent({
    required this.tentId,
    required this.tent,
    required this.onManageTags,
  });

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
              _TagsBlock(
                tentId: tentId,
                tent: displayedTent,
                onManageTags: onManageTags,
              ),
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
                      : () => ref.read(tentEditProvider(tentId).notifier).retryLastUpdate(),
                  onDismiss: () => ref.read(tentEditProvider(tentId).notifier).clearError(),
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
    final semanticColors = context.semanticColors;

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
        padding: AppPadding.inputField,
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
        return TextFieldSheet(
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(sheetContext).pop(true);
            });
          },
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != tent.name) {
        ref
            .read(tentEditProvider(tentId).notifier)
            .updateField(
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
    final theme = Theme.of(context);
    final opacity = isArchived ? AppOpacity.disabled : 1.0;
    final sizeLabel = tent.size == 1 ? '1 place' : '${tent.size} places';
    final modelName = (tent.tentModelName?.trim().isNotEmpty ?? false)
        ? tent.tentModelName!
        : 'Type inconnu';

    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: isArchived,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ScoutPill.state(
              style: tentStateBadgeStyle(context, tent.overallState),
              onTap: () => _showEditStateSheet(context, ref),
              semanticLabel: 'État : ${tent.overallState.toFrenchLabel()}',
            ),
            ScoutPill.neutral(
              label: sizeLabel,
              icon: Icons.people_outline,
              foregroundColor: theme.colorScheme.onSurface,
              borderColor: theme.colorScheme.outlineVariant,
              onTap: () => _showEditSizeSheet(context, ref),
              semanticLabel: 'Taille : $sizeLabel',
            ),
            ScoutPill.neutral(
              label: modelName,
              icon: Icons.terrain_outlined,
              foregroundColor: theme.colorScheme.onSurface,
              borderColor: theme.colorScheme.outlineVariant,
              onTap: () => _showEditModelSheet(context, ref),
              semanticLabel: 'Modèle : $modelName',
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
        return PickerSheet<TentOverallState>(
          title: 'Modifier l\'état',
          items: TentOverallState.values.map((s) {
            final style = tentStateBadgeStyle(sheetContext, s);
            return PickerItem(
              value: s,
              label: style.label,
              color: style.foreground,
              icon: style.icon,
            );
          }).toList(),
          currentValue: tent.overallState,
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && context.mounted && result != tent.overallState) {
      ref
          .read(tentEditProvider(tentId).notifier)
          .updateField(
            tentId: tentId,
            name: tent.name,
            size: tent.size,
            overallState: result,
            comments: tent.comments,
          );
    }
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
        return TextFieldSheet(
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(sheetContext).pop(true);
            });
          },
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newSize = int.tryParse(controller.text.trim());
      if (newSize != null && newSize != tent.size) {
        ref
            .read(tentEditProvider(tentId).notifier)
            .updateField(
              tentId: tentId,
              name: tent.name,
              size: newSize,
              overallState: tent.overallState,
              comments: tent.comments,
            );
      }
    }
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
        return PickerSheet<String>(
          title: 'Modifier le modèle',
          items: models.map((m) => PickerItem(value: m.id, label: m.name)).toList(),
          currentValue: tent.tentModelId,
          onSelected: (modelId) => Navigator.of(sheetContext).pop(modelId),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && context.mounted && result != tent.tentModelId) {
      ref
          .read(tentEditProvider(tentId).notifier)
          .updateModel(
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
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _displayComments(theme),
      ),
    );
  }

  Widget _displayComments(ThemeData theme) {
    final normalized = tent.comments?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const PlaceholderText(text: 'Pas de commentaire');
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
        return TextFieldSheet(
          title: 'Modifier le commentaire',
          controller: controller,
          focusNode: focusNode,
          maxLength: ValidationConstants.tentCommentsMaxLength,
          label: 'Commentaire',
          maxLines: 4,
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onSave: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(sheetContext).pop(true);
          }),
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == true && context.mounted) {
      final newComments = controller.text.trim();
      if (newComments != (tent.comments?.trim() ?? '')) {
        ref
            .read(tentEditProvider(tentId).notifier)
            .updateField(
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
  final VoidCallback onManageTags;

  const _TagsBlock({required this.tentId, required this.tent, required this.onManageTags});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionLabel(
                  label: 'Étiquettes',
                ),
              ),
              _ModifierButton(
                label: 'Modifier',
                onPressed: tent.isArchived ? null : () => _showEditTagsSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tent.tags.isEmpty)
            const PlaceholderText(text: 'Aucune étiquette')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tent.tags
                  .map(
                    (tag) => ScoutPill.tag(
                      label: tag.name,
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
        onManageTags: onManageTags,
      ),
    );
    ref.invalidate(tentDetailProvider(tentId));
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
    await showDeleteConfirmation(
      context: context,
      title: 'Supprimer ces pièces ?',
      content:
          '${_selectedPartIds.length} pièce(s) seront supprimées définitivement. Cette action est irréversible.',
      errorMessage: 'Impossible de supprimer les pièces. Réessayez.',
      barrierDismissible: false,
      onDelete: () async {
        for (final partId in _selectedPartIds.toList()) {
          if (!mounted) throw Exception();
          final success = await ref
              .read(partManagementProvider(widget.tentId).notifier)
              .removePart(partId);
          if (!success) throw Exception();
        }
      },
      onSuccess: () => _exitSelectionMode(),
    );
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
                child: SectionLabel(
                  label: 'Éléments (${widget.parts.length})',
                ),
              ),
              if (!_isSelectionMode)
                _ModifierButton(
                  label: 'Modifier',
                  onPressed: widget.isArchived ? null : _showEditPartsSheet,
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
            const PlaceholderText(text: 'Aucun élément')
          else
            ...widget.parts.map((part) => _buildPartRow(part, theme)),
        ],
      ),
    );
  }

  Widget _buildPartRow(Part part, ThemeData theme) {
    final isSelected = _selectedPartIds.contains(part.id);
    final updateState = ref.watch(partUpdateProvider(widget.tentId));
    final displayedState = updateState.resolveDisplayedState(part);
    final inlineError = updateState.errorFor(part.id);
    final isRemoving = ref
        .watch(partManagementProvider(widget.tentId))
        .removingPartIds
        .contains(part.id);

    return InkWell(
      onTap: widget.isArchived ? null : () => _showEditPartCommentSheet(part),
      onLongPress: widget.isArchived
          ? null
          : () {
              ref.read(partManagementProvider(widget.tentId).notifier).clearRemoveError();
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
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            part.partKindName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!_isSelectionMode)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _partCommentDisplay(part.comments),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontStyle: _hasNoComment(part.comments) ? FontStyle.italic : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSelectionMode) ...[
                    ScoutPill.stateCompact(
                      style: partStateBadgeStyle(context, displayedState),
                    ),
                    const SizedBox(width: 4),
                  ] else
                    ScoutPill.stateCompact(
                      style: partStateBadgeStyle(context, displayedState),
                      onTap: widget.isArchived
                          ? null
                          : () => _showEditPartStateSheet(part, displayedState),
                      semanticLabel: 'État de la pièce : ${displayedState.toFrenchLabel()}',
                    ),
                ],
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
                        onPressed: () =>
                            ref.read(partUpdateProvider(widget.tentId).notifier).retry(part.id),
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

  Future<void> _showEditPartCommentSheet(Part part) async {
    final controller = TextEditingController(text: part.comments ?? '');
    final focusNode = FocusNode();

    final result = await showResponsiveSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return TextFieldSheet(
          title: 'Modifier le commentaire',
          controller: controller,
          focusNode: focusNode,
          maxLength: ValidationConstants.tentCommentsMaxLength,
          label: 'Commentaire',
          maxLines: 4,
          onCancel: () => Navigator.of(sheetContext).pop(false),
          onSave: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(sheetContext).pop(true);
          }),
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result != true || !mounted) return;

    final newComments = controller.text.trim();
    final normalized = newComments.isEmpty ? null : newComments;
    if (normalized == part.comments?.trim() ||
        (normalized == null && (part.comments?.trim().isEmpty ?? true))) {
      return;
    }

    final updateState = ref.read(partUpdateProvider(widget.tentId));
    final displayedState = updateState.resolveDisplayedState(part);

    final notifier = ref.read(partUpdateProvider(widget.tentId).notifier);
    final updateResult = await notifier.updatePartState(
      partId: part.id,
      previousState: displayedState,
      newState: displayedState,
      previousComments: part.comments,
      newComments: normalized,
    );

    if (!mounted) return;
    if (updateResult == PartUpdateResult.success) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  String _partCommentDisplay(String? comments) {
    final normalized = comments?.trim();
    if (normalized == null || normalized.isEmpty) return 'Pas de commentaire';
    return normalized;
  }

  bool _hasNoComment(String? comments) {
    final normalized = comments?.trim();
    return normalized == null || normalized.isEmpty;
  }

  void _showEditPartsSheet() {
    showResponsiveSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AddPartSheet(
        tentId: widget.tentId,
        existingPartKindIds: widget.parts.map((p) => p.partKindId).toSet(),
      ),
    );
  }

  Future<void> _showEditPartStateSheet(Part part, PartState displayedState) async {
    final result = await showResponsiveSheet<PartState>(
      context: context,
      builder: (sheetContext) {
        return PickerSheet<PartState>(
          title: 'Modifier l\'état de l\'élément',
          items: PartState.values.map((s) {
            final style = partStateBadgeStyle(sheetContext, s);
            return PickerItem(
              value: s,
              label: style.label,
              color: style.foreground,
              icon: style.icon,
            );
          }).toList(),
          currentValue: displayedState,
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );

    if (result != null && mounted && result != displayedState) {
      final notifier = ref.read(partUpdateProvider(widget.tentId).notifier);
      final updateResult = await notifier.updatePartState(
        partId: part.id,
        previousState: displayedState,
        newState: result,
        previousComments: part.comments,
        newComments: part.comments,
      );
      if (mounted && updateResult == PartUpdateResult.success) {
        ref.read(successIndicatorProvider.notifier).fire();
      }
    }
  }
}

class _ModifierButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

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
    final semanticColors = context.semanticColors;

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
