import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../screens/tags_screen.dart';

class TagAssignmentSheet extends ConsumerStatefulWidget {
  final String tentId;
  final Set<String> assignedTagIds;

  const TagAssignmentSheet({
    super.key,
    required this.tentId,
    required this.assignedTagIds,
  });

  @override
  ConsumerState<TagAssignmentSheet> createState() => _TagAssignmentSheetState();
}

class _TagAssignmentSheetState extends ConsumerState<TagAssignmentSheet> {
  late Set<String> _selectedTagIds;
  final Set<String> _savingTagIds = {};
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = {...widget.assignedTagIds};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Étiquettes', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _TagLoadError(
                  message: 'Impossible de charger les étiquettes.',
                  onRetry: () => ref.read(tagsProvider.notifier).retry(),
                ),
                data: (tags) => _buildTagContent(tags, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagContent(List<Tag> tags, ThemeData theme) {
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aucune étiquette disponible. Créez d\'abord des étiquettes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TagsScreen())),
              child: const Text('Créer une étiquette'),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredTags = tags.where((tag) {
      if (query.isEmpty) return true;
      return tag.name.toLowerCase().contains(query);
    }).toList();

    if (filteredTags.isEmpty) {
      return const Center(child: Text('Aucune étiquette trouvée'));
    }

    final assigned =
        filteredTags.where((tag) => _selectedTagIds.contains(tag.id)).toList()
          ..sort(_compareTagsByName);
    final unassigned =
        filteredTags.where((tag) => !_selectedTagIds.contains(tag.id)).toList()
          ..sort(_compareTagsByName);

    return ListView(
      children: [
        if (assigned.isNotEmpty) ...[
          Text('Assignées', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _TagWrap(tags: assigned, chipBuilder: _buildChip),
          const SizedBox(height: 16),
        ],
        if (unassigned.isNotEmpty) ...[
          if (assigned.isNotEmpty)
            Text('Disponibles', style: theme.textTheme.titleSmall),
          if (assigned.isNotEmpty) const SizedBox(height: 8),
          _TagWrap(tags: unassigned, chipBuilder: _buildChip),
        ],
      ],
    );
  }

  Widget _buildChip(Tag tag) {
    final tagColor = TagPalette.colorFromHex(tag.color);
    final isSelected = _selectedTagIds.contains(tag.id);
    final isSaving = _savingTagIds.contains(tag.id);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isSaving ? 0.72 : 1,
      child: FilterChip(
        selected: isSelected,
        avatar: isSaving
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : CircleAvatar(backgroundColor: tagColor, radius: 8),
        label: Text(tag.name),
        onSelected: isSaving ? null : (_) => _toggleTag(tag),
      ),
    );
  }

  Future<void> _toggleTag(Tag tag) async {
    final wasSelected = _selectedTagIds.contains(tag.id);
    final nextIds = {..._selectedTagIds};
    if (wasSelected) {
      nextIds.remove(tag.id);
    } else {
      nextIds.add(tag.id);
    }

    setState(() {
      _errorMessage = null;
      _selectedTagIds = nextIds;
      _savingTagIds.add(tag.id);
    });

    try {
      final updatedTent = await ref
          .read(tentRepositoryProvider)
          .setTentTags(tentId: widget.tentId, tagIds: nextIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedTagIds = updatedTent.tags.map((tag) => tag.id).toSet();
      });
      ref.invalidate(tentDetailProvider(widget.tentId));
      ref.invalidate(tentListProvider);
      invalidateTentHistory(ref, widget.tentId);
    } catch (error) {
      if (!mounted) return;
      if (error is! TentRepositoryException) {
        debugPrint('Tag toggle failed: $error');
      }
      final message = error is TentRepositoryException
          ? error.message
          : 'Impossible de modifier les étiquettes. Réessayez.';
      setState(() {
        _selectedTagIds = {..._selectedTagIds}
          ..remove(tag.id)
          ..addAll(wasSelected ? [tag.id] : const <String>[]);
        _errorMessage = message;
      });
      if (error is TentRepositoryException &&
          error.code == ErrorCodes.tagNotFound) {
        await ref.read(tagsProvider.notifier).refresh();
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingTagIds.remove(tag.id);
        });
      }
    }
  }

  int _compareTagsByName(Tag left, Tag right) =>
      left.name.compareTo(right.name);
}

class _TagWrap extends StatelessWidget {
  final List<Tag> tags;
  final Widget Function(Tag tag) chipBuilder;

  const _TagWrap({required this.tags, required this.chipBuilder});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map(chipBuilder).toList(),
    );
  }
}

class _TagLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TagLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
