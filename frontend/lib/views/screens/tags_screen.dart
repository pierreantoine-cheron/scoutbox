import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/providers.dart';
import '../../repositories/tag_repository.dart';
import '../../utils/app_colors.dart';
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
    return AppBarConfig(
      screenId: 'tags',
      title: const Text('Étiquettes'),
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser les étiquettes',
          onPressed: ref.read(tagsProvider).isLoading
              ? null
              : () => ref.read(tagsProvider.notifier).refresh(),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        tooltip: 'Créer une étiquette',
        icon: const Icon(Icons.add),
        label: const Text('Créer une étiquette'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsState = ref.watch(tagsProvider);
    final refreshIssue = ref.watch(tagListRefreshIssueProvider);

    ref.listen(tagsProvider.select((state) => state.isLoading), (_, _) {
      dispatchAppBarConfig();
    });

    return Material(
      child: SafeArea(
        child: tagsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            message: _errorMessage(error),
            onRetry: () => ref.read(tagsProvider.notifier).retry(),
          ),
          data: (tags) => _buildDataState(tags, refreshIssue),
        ),
      ),
    );
  }

  Widget _buildDataState(List<Tag> tags, Object? refreshIssue) {
    if (tags.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (refreshIssue != null)
              _RefreshWarningCard(message: _refreshWarning(refreshIssue)),
            const SizedBox(height: 96),
            const Icon(Icons.label_outline, size: 64),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Aucune étiquette disponible',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('Créez votre première étiquette.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(tagsProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: tags.length + (refreshIssue == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (refreshIssue != null && index == 0) {
            return _RefreshWarningCard(message: _refreshWarning(refreshIssue));
          }

          final tagIndex = refreshIssue == null ? index : index - 1;
          final tag = tags[tagIndex];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: TagPalette.colorFromHex(tag.color),
              ),
              title: Text(tag.name),
              subtitle: Text(
                '${tag.tentCount} tente${tag.tentCount > 1 ? 's' : ''}',
              ),
              trailing: TagChip(
                name: tag.name,
                color: TagPalette.colorFromHex(tag.color),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TagCreationDialog(
        onCreate: (name, color) =>
            ref.read(tagsProvider.notifier).createTag(name: name, color: color),
      ),
    );

    if (created == true && mounted) {
      ref.read(successIndicatorProvider.notifier).fire();
    }
  }

  String _errorMessage(Object error) {
    return error is TagRepositoryException
        ? error.message
        : 'Impossible de charger les étiquettes. Réessayez.';
  }

  String _refreshWarning(Object issue) {
    final detail = issue is TagRepositoryException
        ? issue.message
        : 'Impossible d\'actualiser les étiquettes pour le moment.';
    return 'Les données affichées peuvent être anciennes. $detail';
  }
}

class _RefreshWarningCard extends StatelessWidget {
  final String message;

  const _RefreshWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

    return Card(
      color: semanticColors.warningContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: semanticColors.onWarningContainer),
        ),
      ),
    );
  }
}
