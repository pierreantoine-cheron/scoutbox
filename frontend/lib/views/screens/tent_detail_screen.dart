import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/part.dart';
import '../../models/tent.dart';
import '../../providers/tent_detail_provider.dart';
import '../../repositories/tent_repository.dart';
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
          data: (tent) => _DetailContent(tent: tent),
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

class _DetailContent extends StatelessWidget {
  final Tent tent;

  const _DetailContent({required this.tent});

  @override
  Widget build(BuildContext context) {
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
              _HeaderSection(tent: tent),
              const SizedBox(height: 16),
              _CommentsSection(comments: tent.comments),
              const SizedBox(height: 16),
              _PartsSection(parts: tent.parts),
              const SizedBox(height: 16),
              _AuditSection(tent: tent),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Tent tent;

  const _HeaderSection({required this.tent});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tent.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StateBadge.forTent(context, tent.overallState),
                _InfoChip(
                  icon: Icons.people_outline,
                  label: tent.size == 1 ? '1 place' : '${tent.size} places',
                ),
                _InfoChip(
                  icon: Icons.terrain_outlined,
                  label: _shapeLabel(tent.tentShapeName),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _DisabledActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Modifier',
                ),
                _DisabledActionButton(
                  icon: Icons.archive_outlined,
                  label: 'Archiver',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bientôt disponible',
              style: Theme.of(context).textTheme.bodySmall,
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

class _CommentsSection extends StatelessWidget {
  final String? comments;

  const _CommentsSection({required this.comments});

  @override
  Widget build(BuildContext context) {
    final normalized = comments?.trim();
    final display = normalized == null || normalized.isEmpty
        ? 'Aucun commentaire'
        : normalized;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commentaires',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(display),
          ],
        ),
      ),
    );
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

class _DisabledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DisabledActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: '$label bientôt disponible',
      child: OutlinedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
