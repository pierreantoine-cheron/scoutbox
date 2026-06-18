import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import '../../services/error_localizer.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import '../../utils/constants.dart';
import '../screens/tags_screen.dart';
import 'sheet_handle.dart';
import 'tag_chip.dart';

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
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(
              'Modifier les étiquettes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              'Rechercher',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher une étiquette...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: tagsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _TagLoadError(
                message: 'Impossible de charger les étiquettes.',
                onRetry: () => ref.read(tagsProvider.notifier).retry(),
              ),
              data: (tags) => _buildTagContent(tags),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
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
              'Aucune étiquette disponible. Créez d\'abord des étiquettes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsScreen()),
              ),
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
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (filteredTags.isEmpty) {
      return const Center(child: Text('Aucune étiquette trouvée'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: filteredTags
            .map((tag) => SelectableTagChip(
                  name: tag.name,
                  color: TagPalette.colorFromHex(tag.color),
                  selected: _selectedTagIds.contains(tag.id),
                  onTap: _isSaving ? null : () => _toggleLocal(tag.id),
                ))
            .toList(),
      ),
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
          : 'Impossible de modifier les étiquettes. Réessayez.';
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


class _TagLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TagLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
