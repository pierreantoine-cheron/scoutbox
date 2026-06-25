import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/part_kind.dart';
import '../../providers/providers.dart';
import '../../utils/design_constants.dart';
import '../../utils/error_messages.dart';
import '../../utils/responsive_sheet.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class PartKindsScreen extends ConsumerStatefulWidget {
  const PartKindsScreen({super.key});

  @override
  ConsumerState<PartKindsScreen> createState() => _PartKindsScreenState();
}

class _PartKindsScreenState extends ConsumerState<PartKindsScreen>
    with RouteAware, RouteAwareAppBarMixin<PartKindsScreen> {
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
    final partKindCount = ref.read(partKindsProvider).value?.length ?? 0;
    final isLoading = ref.read(partKindsProvider).isLoading;

    return AppBarConfig(
      screenId: 'parts',
      actions: [
        if (partKindCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CountBadge(count: partKindCount, label: 'élément'),
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
              tooltip: 'Actualiser les éléments',
              onPressed: isLoading ? null : () => ref.read(partKindsProvider.notifier).refresh(),
            );
          },
        ),
      ],
      fab: FloatingActionButton(
        onPressed: () => _showCreateSheet(),
        tooltip: 'Créer un élément',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partKindsState = ref.watch(partKindsProvider);
    final refreshIssue = ref.watch(partKindsRefreshIssueProvider);

    ref.listen(partKindsProvider, (_, _) {
      dispatchAppBarConfig();
    });

    return DataScreenScaffold<List<PartKind>>(
      state: partKindsState,
      errorFallbackMessage: 'Impossible de charger les éléments.',
      onRetry: () => ref.read(partKindsProvider.notifier).retry(),
      builder: (partKinds) => _buildDataState(partKinds, refreshIssue),
    );
  }
  Widget _buildDataState(List<PartKind> partKinds, Object? refreshIssue) {
    return ResponsiveItemList<PartKind>(
      items: partKinds,
      itemContent: (context, pk) => _PartKindContent(partKind: pk),
      onRefresh: () => ref.read(partKindsProvider.notifier).refresh(),
      refreshWarning: refreshIssue != null ? _refreshWarning(refreshIssue) : null,
      emptyState: const EmptyStateView(
        icon: Icons.build_outlined,
        title: 'Aucun élément',
        subtitle: 'Créez des types d\'éléments pour composer vos modèles de tentes.',
      ),
      onEdit: (pk) => _showRenameSheet(pk),
      onDelete: (pk) => _showDeleteDialog(pk),
    );
  }

  Future<void> _showCreateSheet() async {
    final created = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => PartKindSheet(
        onSave: (name) => ref.read(partKindsProvider.notifier).createPartKind(name: name),
      ),
    );

    if (created == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  Future<void> _showRenameSheet(PartKind partKind) async {
    final renamed = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => PartKindSheet(
        initialName: partKind.name,
        onSave: (name) =>
            ref.read(partKindsProvider.notifier).renamePartKind(partKind.id, name: name),
      ),
    );

    if (renamed == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  Future<void> _showDeleteDialog(PartKind partKind) async {
    final count = partKind.tentCount;
    final content = count > 0
        ? 'L\'élément "${partKind.name}" sera supprimé. $count tente(s) l\'utilisent.'
        : 'L\'élément "${partKind.name}" sera supprimé.';

    await showDeleteConfirmation(
      context: context,
      title: 'Supprimer l\'élément ?',
      content: content,
      errorMessage: 'Impossible de supprimer l\'élément. Réessayez.',
      onDelete: () => ref.read(partKindsProvider.notifier).deletePartKind(partKind.id),
      onSuccess: () {
        if (mounted) ref.read(successIndicatorProvider.notifier).fire();
      },
    );
  }

  String _refreshWarning(Object issue) {
    final detail = toUserFacingError(
      issue,
      'Impossible d\'actualiser les éléments pour le moment.',
    );
    return 'Les données affichées peuvent être anciennes. $detail';
  }
}

class _PartKindContent extends StatelessWidget {
  final PartKind partKind;

  const _PartKindContent({required this.partKind});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                partKind.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              CountBadge(count: partKind.tentCount, label: 'tente'),
            ],
          ),
        ),
      ],
    );
  }
}
