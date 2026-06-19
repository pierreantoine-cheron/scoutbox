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
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser les étiquettes',
          onPressed: isLoading
              ? null
              : () => ref.read(tagsProvider.notifier).refresh(),
        ),
        const LogoutButton(),
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
    if (tags.isEmpty) {
      return _buildEmptyState(refreshIssue);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100
              ? 3
              : width >= 768
              ? 2
              : 1;
          final spacing = AppSpacing.sm;
          final cardWidth =
              (width - 2 * 16 - (crossAxisCount - 1) * spacing) /
              crossAxisCount;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (refreshIssue != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: RefreshWarningCard(
                    message: _refreshWarning(refreshIssue),
                  ),
                ),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: tags.map((tag) {
                  return SizedBox(
                    width: cardWidth,
                    child: _TagCard(tag: tag),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Object? refreshIssue) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (refreshIssue != null)
            RefreshWarningCard(message: _refreshWarning(refreshIssue)),
          const SizedBox(height: 96),
          const Icon(Icons.label_outline, size: 48, color: AppColors.muted),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Aucune étiquette',
              style: TextStyle(fontSize: 17, color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Créez des étiquettes pour organiser vos tentes.',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => _showCreateSheet(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nouvelle étiquette'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    final created = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => TagSheet(
        onCreate: (name, color) =>
            ref.read(tagsProvider.notifier).createTag(name: name, color: color),
      ),
    );

    if (created == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }


  String _refreshWarning(Object issue) {
    final detail = toUserFacingError(issue, 'Impossible d\'actualiser les étiquettes pour le moment.');
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

class _TagCard extends StatelessWidget {
  final Tag tag;

  const _TagCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = TagPalette.colorFromHex(tag.color);

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
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
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                offset: const Offset(0, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  side: const BorderSide(color: AppColors.border),
                ),
                elevation: AppElevation.dropdown,
                color: colorScheme.surface,
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    enabled: false,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: AppColors.muted),
                        SizedBox(width: AppSpacing.sm),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    enabled: false,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.stateUnusable,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Supprimer',
                          style: TextStyle(color: AppColors.stateUnusable),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
