import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

class AddPartSheet extends ConsumerStatefulWidget {
  final String tentId;
  final Set<String> existingPartKindIds;

  const AddPartSheet({
    super.key,
    required this.tentId,
    required this.existingPartKindIds,
  });

  @override
  ConsumerState<AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends ConsumerState<AddPartSheet> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(partManagementProvider(widget.tentId).notifier).loadPartKinds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partManagementProvider(widget.tentId));
    final theme = Theme.of(context);
    final canSubmit =
        _selectedIds.isNotEmpty &&
        !state.isAdding &&
        !_hasEmptySearchResults(state);

    return FractionallySizedBox(
      heightFactor: 0.9,
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
            Text('Ajouter une pièce', style: theme.textTheme.titleLarge),
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
            if (state.isLoadingPartKinds)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Chargement des pièces…'),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.partKindsError != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    state.partKindsError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
            else
              Expanded(child: _buildPartKindList(state, theme)),
            if (state.addError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.addError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSubmit ? _onConfirm : null,
                    child: state.isAdding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasEmptySearchResults(PartManagementState state) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return false;
    return !state.partKinds.any((pk) => pk.name.toLowerCase().contains(query));
  }

  Widget _buildPartKindList(PartManagementState state, ThemeData theme) {
    final query = _searchController.text.trim().toLowerCase();
    final partKinds = state.partKinds.where((pk) {
      if (query.isEmpty) return true;
      return pk.name.toLowerCase().contains(query);
    }).toList();

    final existingIds = widget.existingPartKindIds;

    if (partKinds.isEmpty && query.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucun type de pièce trouvé',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final existingPartKinds = partKinds
        .where((pk) => existingIds.contains(pk.id))
        .toList();
    final availablePartKinds = partKinds
        .where((pk) => !existingIds.contains(pk.id))
        .toList();

    final allPresent = availablePartKinds.isEmpty && partKinds.isNotEmpty;

    return ListView(
      children: [
        if (allPresent)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Toutes les pièces sont déjà présentes sur cette tente.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...availablePartKinds.map(
          (pk) => CheckboxListTile(
            value: _selectedIds.contains(pk.id),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedIds.add(pk.id);
                } else {
                  _selectedIds.remove(pk.id);
                }
              });
            },
            title: Text(pk.name),
            subtitle: Text('Ordre : ${pk.displayOrder}'),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ),
        if (existingPartKinds.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Déjà présente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ...existingPartKinds.map(
            (pk) => CheckboxListTile(
              value: false,
              onChanged: null,
              title: Text(
                pk.name,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              subtitle: Text(
                'Ordre : ${pk.displayOrder}',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onConfirm() async {
    final success = await ref
        .read(partManagementProvider(widget.tentId).notifier)
        .addParts(_selectedIds.toList());
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }
}
