import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../screens/tags_screen.dart';
import 'scout_pill.dart';
import 'sheet_scaffold.dart';
import 'async_error_view.dart';

class TagAssignmentSheet extends ConsumerStatefulWidget {
  final String tentId;
  final Set<String> assignedTagIds;

  const TagAssignmentSheet({
    super.key,
    required this.tentId,
    required this.assignedTagIds,
  });

  @override
  ConsumerState<TagAssignmentSheet> createState() =>
      _TagAssignmentSheetState();
}

class _TagAssignmentSheetState extends ConsumerState<TagAssignmentSheet> {
  late Set<String> _selectedTagIds;
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

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

    return SheetScaffold(
      title: 'Modifier les \u00e9tiquettes',
      errorMessage: _errorMessage,
      isLoading: _isSaving,
      onCancel: () => Navigator.of(context).pop(),
      onSave: _onSave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            'Rechercher',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Rechercher une \u00e9tiquette...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          tagsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(
              message: 'Impossible de charger les \u00e9tiquettes.',
              onRetry: () => ref.read(tagsProvider.notifier).retry(),
            ),
            data: (tags) => _buildTagContent(tags),
          ),
        ],
      ),
    );
  }

  Widget _buildTagContent(List<Tag> tags) {
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aucune \u00e9tiquette disponible. Cr\u00e9ez d\'abord des \u00e9tiquettes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsScreen()),
              ),
              child: const Text('Cr\u00e9er une \u00e9tiquette'),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredTags = tags.where((tag) {
      if (query.isEmpty) return true;
      return tag.name.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (filteredTags.isEmpty) {
      return const Center(child: Text('Aucune \u00e9tiquette trouv\u00e9e'));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filteredTags
          .map((tag) {
                final tagColor = TagPalette.colorFromHex(tag.color);
                final isSelected = _selectedTagIds.contains(tag.id);
                return ScoutPill.tagFilter(
                  label: tag.name,
                  color: tagColor,
                  selected: isSelected,
                  onTap: _isSaving ? null : () => _toggleLocal(tag.id),
                );
              })
          .toList(),
    );
  }

  void _toggleLocal(String tagId) {
    setState(() {
      _errorMessage = null;
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  Future<void> _onSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedTent = await ref
          .read(tentRepositoryProvider)
          .setTentTags(
            tentId: widget.tentId,
            tagIds: _selectedTagIds.toList(),
          );

      if (!mounted) return;

      ref.invalidate(tentDetailProvider(widget.tentId));
      ref.invalidate(tentListProvider);
      invalidateTentHistory(ref, widget.tentId);

      Navigator.of(context).pop(updatedTent);
    } catch (error) {
      if (!mounted) return;

      final message = error is TentRepositoryException
          ? ErrorLocalizer.localize(error.code, fallback: error.message)
          : 'Impossible de modifier les \u00e9tiquettes. R\u00e9essayez.';
      setState(() {
        _errorMessage = message;
      });

      if (error is TentRepositoryException &&
          error.code == ErrorCodes.tagNotFound) {
        await ref.read(tagsProvider.notifier).refresh();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
