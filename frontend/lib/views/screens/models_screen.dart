import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tent_model.dart';
import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import '../../utils/error_messages.dart';
import '../../utils/responsive_sheet.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen>
    with RouteAware, RouteAwareAppBarMixin<ModelsScreen> {
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
    final modelCount = ref.read(tentModelsProvider).value?.length ?? 0;
    final isLoading = ref.read(tentModelsProvider).isLoading;

    return AppBarConfig(
      screenId: 'models',
      actions: [
        if (modelCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CountBadge(count: modelCount, label: 'modèle'),
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
              tooltip: 'Actualiser les modèles',
              onPressed:
                  isLoading ? null : () => ref.read(tentModelsProvider.notifier).refresh(),
            );
          },
        ),
      ],
      fab: FloatingActionButton(
        onPressed: () => _showCreateSheet(),
        tooltip: 'Créer un modèle',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsState = ref.watch(tentModelsProvider);

    ref.listen(tentModelsProvider, (_, _) {
      dispatchAppBarConfig();
    });

    return DataScreenScaffold<List<TentModel>>(
      state: modelsState,
      errorFallbackMessage: 'Impossible de charger les modèles.',
      onRetry: () => ref.read(tentModelsProvider.notifier).retry(),
      builder: (models) => _buildDataState(models),
    );
  }

  Widget _buildDataState(List<TentModel> models) {
    return ResponsiveItemList<TentModel>(
      items: models,
      itemContent: (context, model) => _ModelContent(model: model),
      onRefresh: () => ref.read(tentModelsProvider.notifier).refresh(),
      refreshWarning: null,
      emptyState: EmptyStateView(
        icon: NavigationSection.models.icon,
        title: 'Aucun modèle',
        subtitle: 'Créez un modèle de tente avec ses éléments.',
      ),
      onEdit: (model) => _showEditSheet(model),
      onDelete: (model) => _showDeleteDialog(model),
    );
  }

  Future<void> _showCreateSheet() async {
    final created = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => TentModelSheet(
        onSave: (name, componentIds) =>
            ref.read(tentModelsProvider.notifier).createModel(name: name, componentIds: componentIds),
      ),
    );

    if (created == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  Future<void> _showEditSheet(TentModel model) async {
    final updated = await showResponsiveSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => TentModelSheet(
        initialName: model.name,
        initialComponentIds: model.componentIds,
        onSave: (name, componentIds) =>
            ref.read(tentModelsProvider.notifier).updateModel(model.id, name: name, componentIds: componentIds),
      ),
    );

    if (updated == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  Future<void> _showDeleteDialog(TentModel model) async {
    final hasTents = model.tentCount > 0;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le modèle ?',
      content: hasTents
          ? 'Le modèle "${model.name}" est utilisé par ${model.tentCount} tente${model.tentCount != 1 ? 's' : ''}. Impossible de le supprimer.'
          : 'Le modèle "${model.name}" sera supprimé.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
      enabled: !hasTents,
    );

    if (!confirmed) return;

    try {
      await ref.read(tentModelsProvider.notifier).deleteModel(model.id);
      if (mounted) {
        ref.read(successIndicatorProvider.notifier).fire();
      }
    } catch (error) {
      if (mounted) {
        showErrorDialog(
          context,
          toUserFacingError(
            error,
            'Impossible de supprimer le modèle. Réessayez.',
          ),
        );
      }
    }
  }
}

class _ModelContent extends StatelessWidget {
  final TentModel model;

  const _ModelContent({required this.model});

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
                model.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${model.tentCount} tente${model.tentCount != 1 ? 's' : ''} · '
                '${model.componentCount} élément${model.componentCount != 1 ? 's' : ''}',
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