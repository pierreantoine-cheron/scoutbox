import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tent.dart';
import '../../providers/app_bar_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_observer_provider.dart';
import '../../providers/success_indicator_provider.dart';
import '../../providers/tent_filter_provider.dart';
import '../../providers/tent_list_provider.dart';
import '../../providers/tent_shapes_provider.dart';
import '../../repositories/tent_repository.dart';
import '../widgets/tent_card.dart';
import '../widgets/tent_data_table.dart';
import '../widgets/tent_list_filter_bar.dart';
import 'tent_creation_screen.dart';
import 'tent_detail_screen.dart';

class TentListScreen extends ConsumerStatefulWidget {
  const TentListScreen({super.key});

  @override
  ConsumerState<TentListScreen> createState() => _TentListScreenState();
}

class _TentListScreenState extends ConsumerState<TentListScreen>
    with RouteAware {
  late final TextEditingController _searchController;
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    _scheduleConfigUpdate();
  }

  @override
  void didPopNext() {
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

    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final authState = ref.read(authProvider);
    final tentsState = ref.read(tentListProvider);

    ref
        .read(appBarConfigProvider.notifier)
        .set(
          AppBarConfig(
            screenId: 'tent_list',
            title: const Text('ScoutBox - Tentes'),
            actions: [
              if (isDesktop)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser la liste',
                  onPressed: tentsState.isLoading
                      ? null
                      : () => ref.read(tentListProvider.notifier).refresh(),
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: authState.isLoading
                    ? null
                    : () => _showLogoutConfirmationDialog(context, ref),
              ),
            ],
            fab: FloatingActionButton(
              onPressed: () => _openTentCreation(context),
              tooltip: 'Ajouter une tente',
              child: const Icon(Icons.add),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tentsState = ref.watch(tentListProvider);
    final filterState = ref.watch(tentListFilterProvider);
    final filteredTents = ref.watch(filteredTentListProvider);
    final refreshIssue = ref.watch(tentListRefreshIssueProvider);
    final isFilteredMode = ref.watch(tentListFilteredModeProvider);

    ref.listen(
      tentListFilterProvider.select((state) => state.searchText),
      (_, searchText) => _syncSearchController(searchText),
    );
    ref.listen(
      authProvider.select((state) => state.isLoading),
      (_, _) => _scheduleConfigUpdate(),
    );
    ref.listen(
      tentListProvider.select((state) => state.isLoading),
      (_, _) => _scheduleConfigUpdate(),
    );

    return Material(
      child: SafeArea(
        child: tentsState.when(
          loading: _buildLoadingState,
          error: (error, _) => _buildErrorState(error),
          data: (tents) => _buildDataState(
            rawTents: tents,
            visibleTents: filteredTents,
            refreshIssue: refreshIssue,
            isFilteredMode: isFilteredMode,
            filterState: filterState,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, _) => const _TentCardSkeleton(),
    );
  }

  Widget _buildErrorState(Object error) {
    return TentListInlineErrorState(
      error: error,
      onRetry: () => ref.read(tentListProvider.notifier).retry(),
    );
  }

  Widget _buildDataState({
    required List<Tent> rawTents,
    required List<Tent> visibleTents,
    required Object? refreshIssue,
    required bool isFilteredMode,
    required TentListFilterState filterState,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final availableSizes = _buildSizeOptions(rawTents);
    final availableShapeOptions = _buildShapeOptions(rawTents);

    if (rawTents.isEmpty && !isFilteredMode) {
      return Column(
        children: [
          _buildFilterBar(
            filterState,
            isFilteredMode,
            isDesktop,
            availableSizes,
            availableShapeOptions,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(tentListProvider.notifier).refresh(),
              child: _EmptyState(
                onCreateTent: () => _openTentCreation(context),
                warningMessage: _toRefreshWarningMessage(refreshIssue),
              ),
            ),
          ),
        ],
      );
    }

    if (visibleTents.isEmpty) {
      return Column(
        children: [
          _buildFilterBar(
            filterState,
            isFilteredMode,
            isDesktop,
            availableSizes,
            availableShapeOptions,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(tentListProvider.notifier).refresh(),
              child: _FilteredEmptyState(
                onClearFilters: _clearFiltersHook,
                warningMessage: _toRefreshWarningMessage(refreshIssue),
              ),
            ),
          ),
        ],
      );
    }

    if (isDesktop) {
      final warning = _toRefreshWarningMessage(refreshIssue);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(
            filterState,
            isFilteredMode,
            isDesktop,
            availableSizes,
            availableShapeOptions,
          ),
          if (warning != null) _RefreshWarningCard(message: warning),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TentDataTable(
                tents: visibleTents,
                onOpenTent: (tent) => _openTentDetail(context, tent),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildFilterBar(
          filterState,
          isFilteredMode,
          isDesktop,
          availableSizes,
          availableShapeOptions,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(tentListProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: visibleTents.length + (refreshIssue == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (refreshIssue != null && index == 0) {
                  return _RefreshWarningCard(
                    message: _toRefreshWarningMessage(refreshIssue)!,
                  );
                }

                final tentIndex = refreshIssue == null ? index : index - 1;
                final tent = visibleTents[tentIndex];
                return TentCard(
                  tent: tent,
                  onTap: () => _openTentDetail(context, tent),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(
    TentListFilterState filterState,
    bool isFilteredMode,
    bool isDesktop,
    List<int> availableSizes,
    List<TentTypeFilterOption> availableShapeOptions,
  ) {
    return TentListFilterBar(
      isDesktop: isDesktop,
      searchController: _searchController,
      selectedStates: filterState.selectedStates,
      selectedSizes: filterState.selectedSizes,
      selectedShapeIds: filterState.selectedShapeIds,
      availableSizes: availableSizes,
      availableShapeOptions: availableShapeOptions,
      isFilteredMode: isFilteredMode,
      onSearchChanged: (value) {
        ref.read(tentListFilterProvider.notifier).setSearchText(value);
      },
      onToggleState: (state) {
        ref.read(tentListFilterProvider.notifier).toggleState(state);
      },
      onToggleSize: (size) {
        ref.read(tentListFilterProvider.notifier).toggleSize(size);
      },
      onToggleShape: (shapeId) {
        ref.read(tentListFilterProvider.notifier).toggleShape(shapeId);
      },
      onClearAll: _clearFiltersHook,
    );
  }

  List<int> _buildSizeOptions(List<Tent> rawTents) {
    final options = rawTents.map((tent) => tent.size).toSet().toList();
    options.sort();
    return options;
  }

  List<TentTypeFilterOption> _buildShapeOptions(List<Tent> rawTents) {
    final rawShapeIds = rawTents.map((tent) => tent.tentShapeId).toSet();
    final rawShapeLabels = <String, String>{
      for (final tent in rawTents)
        if ((tent.tentShapeName ?? '').trim().isNotEmpty)
          tent.tentShapeId: tent.tentShapeName!.trim(),
    };

    final shapeMetadata =
        ref.watch(tentShapesProvider).asData?.value ?? const [];
    final options = <TentTypeFilterOption>[];
    final includedIds = <String>{};

    for (final shape in shapeMetadata) {
      if (!rawShapeIds.contains(shape.id)) {
        continue;
      }

      options.add(TentTypeFilterOption(id: shape.id, label: shape.name));
      includedIds.add(shape.id);
    }

    final missingIds =
        rawShapeIds.where((id) => !includedIds.contains(id)).toList()..sort();

    for (final shapeId in missingIds) {
      options.add(
        TentTypeFilterOption(
          id: shapeId,
          label: rawShapeLabels[shapeId] ?? 'Type inconnu',
        ),
      );
    }

    return options;
  }

  void _syncSearchController(String searchText) {
    if (_searchController.text == searchText) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: searchText,
      selection: TextSelection.collapsed(offset: searchText.length),
    );
  }

  Future<void> _openTentCreation(BuildContext context) async {
    final createdTent = await Navigator.of(
      context,
    ).push<Tent>(MaterialPageRoute(builder: (_) => const TentCreationScreen()));

    if (createdTent == null || !mounted) {
      return;
    }

    ref.read(successIndicatorProvider.notifier).fire();
    ref.read(tentListProvider.notifier).showTent(createdTent);
    await ref.read(tentListProvider.notifier).refresh();
  }

  String? _toRefreshWarningMessage(Object? refreshIssue) {
    if (refreshIssue == null) {
      return null;
    }

    final detail = refreshIssue is TentRepositoryException
        ? refreshIssue.message
        : 'Impossible d\'actualiser la liste pour le moment.';
    return 'Les données affichées peuvent être anciennes. $detail';
  }

  Future<void> _openTentDetail(BuildContext context, Tent tent) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TentDetailScreen(tentId: tent.id)),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text('Votre session sera fermée.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
              },
              child: const Text('Déconnecter'),
            ),
          ],
        );
      },
    );
  }

  void _clearFiltersHook() {
    ref.read(tentListFilterProvider.notifier).clearAll();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTent;
  final String? warningMessage;

  const _EmptyState({required this.onCreateTent, this.warningMessage});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (warningMessage != null)
          _RefreshWarningCard(message: warningMessage!),
        const SizedBox(height: 72),
        const Icon(Icons.cabin, size: 64),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Aucune tente disponible',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('Commencez par créer votre première tente.')),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: onCreateTent,
            icon: const Icon(Icons.add),
            label: const Text('Créer une tente'),
          ),
        ),
      ],
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final VoidCallback onClearFilters;
  final String? warningMessage;

  const _FilteredEmptyState({
    required this.onClearFilters,
    this.warningMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (warningMessage != null)
          _RefreshWarningCard(message: warningMessage!),
        const SizedBox(height: 72),
        const Icon(Icons.filter_alt_off, size: 64),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Aucune tente ne correspond à vos critères',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: onClearFilters,
            child: const Text('Effacer les filtres'),
          ),
        ),
      ],
    );
  }
}

class TentListInlineErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const TentListInlineErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = error is TentRepositoryException
        ? (error as TentRepositoryException).message
        : 'Impossible de charger les tentes. Réessayez.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}

class _RefreshWarningCard extends StatelessWidget {
  final String message;

  const _RefreshWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _TentCardSkeleton extends StatelessWidget {
  const _TentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(widthFactor: 0.6, height: 18),
            SizedBox(height: 10),
            _SkeletonLine(widthFactor: 0.35, height: 14),
            SizedBox(height: 8),
            _SkeletonLine(widthFactor: 0.45, height: 14),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonLine({required this.widthFactor, required this.height});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
