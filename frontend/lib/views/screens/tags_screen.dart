import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import '../../utils/error_messages.dart';
import '../../utils/responsive_sheet.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen>
    with RouteAware, RouteAwareAppBarMixin<TagsScreen> {
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
  void didPopNext() {
    dispatchAppBarConfig();
  }

  @override
  AppBarConfig buildAppBarConfig() {
    final tagCount = ref.read(tagsProvider).value?.length ?? 0;
    final isLoading = ref.read(tagsProvider).isLoading;

    return AppBarConfig(
      screenId: 'tags',
      actions: [
        if (tagCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _CountBadge(count: tagCount),
          ),
        Builder(
          builder: (context) {
            final isDesktop = MediaQuery.of(context).size.width >= 768;
            if (!isDesktop) return const SizedBox.shrink();
            return DesktopCreateButton(
              label: 'Créer',
              onPressed: () => _showCreateSheet(),
            );
          },
        ),
        Builder(
          builder: (context) {
            final isDesktop = MediaQuery.of(context).size.width >= 768;
            if (!isDesktop) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser les étiquettes',
              onPressed: isLoading ? null : () => ref.read(tagsProvider.notifier).refresh(),
            );
          },
        ),
      ],
      fab: FloatingActionButton(
        onPressed: () => _showCreateSheet(),
        tooltip: 'Créer une étiquette',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsState = ref.watch(tagsProvider);
    final refreshIssue = ref.watch(tagListRefreshIssueProvider);

    ref.listen(tagsProvider, (_, _) {
      dispatchAppBarConfig();
    });

    return DataScreenScaffold<List<Tag>>(
      state: tagsState,
      errorFallbackMessage: 'Impossible de charger les étiquettes.',
      onRetry: () => ref.read(tagsProvider.notifier).retry(),
      builder: (tags) => _buildDataState(tags, refreshIssue),
    );
  }

  Widget _buildDataState(List<Tag> tags, Object? refreshIssue) {
    return ResponsiveItemList<Tag>(
      items: tags,
      itemContent: (context, tag) => _TagContent(tag: tag),
      onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
      refreshWarning: refreshIssue != null ? _refreshWarning(refreshIssue) : null,
      emptyState: const EmptyStateView(
        icon: Icons.label_outline,
        title: 'Aucune étiquette',
        subtitle: 'Créez des étiquettes pour organiser vos tentes.',
      ),
      onEdit: (tag) => _showEditSheet(tag),
      onDelete: (tag) => _showDeleteDialog(tag),
    );
  }

  Future<void> _showEditSheet(Tag tag) async {
    final renamed = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => TagSheet(
        initialName: tag.name,
        initialColor: tag.color,
        onSave: (name, color) =>
            ref.read(tagsProvider.notifier).updateTag(tag.id, name: name, color: color),
      ),
    );

    if (renamed == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  Future<void> _showDeleteDialog(Tag tag) async {
    final count = tag.tentCount;
    final content = count > 0
        ? 'L\'étiquette "${tag.name}" sera supprimée. $count tente(s) l\'utilisent.'
        : 'L\'étiquette "${tag.name}" sera supprimée.';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer l\'étiquette ?',
      content: content,
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      await ref.read(tagsProvider.notifier).deleteTag(tag.id);
      if (mounted) {
        ref.read(successIndicatorProvider.notifier).fire();
      }
    } catch (error) {
      if (mounted) {
        showErrorDialog(
          context,
          toUserFacingError(
            error,
            'Impossible de supprimer l\'étiquette. Réessayez.',
          ),
        );
      }
    }
  }

  Future<void> _showCreateSheet() async {
    final created = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => TagSheet(
        onSave: (name, color) =>
            ref.read(tagsProvider.notifier).createTag(name: name, color: color),
      ),
    );

    if (created == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  String _refreshWarning(Object issue) {
    final detail = toUserFacingError(
      issue,
      'Impossible d\'actualiser les étiquettes pour le moment.',
    );
    return 'Les données affichées peuvent être anciennes. $detail';
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count étiquette${count > 1 ? 's' : ''}',
      style: const TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        color: AppColors.muted,
      ),
    );
  }
}

class _TagContent extends StatelessWidget {
  final Tag tag;

  const _TagContent({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = TagPalette.colorFromHex(tag.color);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tagColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tagColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tag.tentCount} tente${tag.tentCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
