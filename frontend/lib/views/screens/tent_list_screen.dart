import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tent.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tent_list_provider.dart';
import '../../repositories/tent_repository.dart';
import '../widgets/tent_card.dart';
import 'tent_creation_screen.dart';

class TentListScreen extends ConsumerStatefulWidget {
  const TentListScreen({super.key});

  @override
  ConsumerState<TentListScreen> createState() => _TentListScreenState();
}

class _TentListScreenState extends ConsumerState<TentListScreen> {
  static const bool _isFilteredMode = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tentsState = ref.watch(tentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScoutBox - Tentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: authState.isLoading
                ? null
                : () => _showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: tentsState.when(
          loading: _buildLoadingState,
          error: (error, _) => _buildErrorState(error),
          data: (tents) => _buildDataState(tents),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTentCreation(context),
        tooltip: 'Ajouter une tente',
        child: const Icon(Icons.add),
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
    final message = error is TentRepositoryException
        ? error.message
        : 'Impossible de charger les tentes. Réessayez.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(tentListProvider.notifier).retry(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataState(List<Tent> tents) {
    if (tents.isEmpty) {
      if (_isFilteredMode) {
        return _FilteredEmptyState(onClearFilters: _clearFiltersHook);
      }

      return _EmptyState(onCreateTent: () => _openTentCreation(context));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(tentListProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tents.length,
        itemBuilder: (context, index) {
          final tent = tents[index];
          return TentCard(
            tent: tent,
            onTap: () => _openTentDetailStub(context, tent),
          );
        },
      ),
    );
  }

  Future<void> _openTentCreation(BuildContext context) async {
    final createdTent = await Navigator.of(
      context,
    ).push<Tent>(MaterialPageRoute(builder: (_) => const TentCreationScreen()));

    if (createdTent == null || !mounted) {
      return;
    }

    await ref.read(tentListProvider.notifier).refresh();
  }

  Future<void> _openTentDetailStub(BuildContext context, Tent tent) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TentDetailStubScreen(tentName: tent.name),
      ),
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

  void _clearFiltersHook() {}
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTent;

  const _EmptyState({required this.onCreateTent});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
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

  const _FilteredEmptyState({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
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

class TentDetailStubScreen extends StatelessWidget {
  final String tentName;

  const TentDetailStubScreen({super.key, required this.tentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la tente')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Le détail de "$tentName" sera disponible dans la Story 2.7.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
