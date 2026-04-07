import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tent.dart';
import '../../models/tent_shape.dart';
import '../../providers/tent_creation_provider.dart';
import '../../providers/tent_shapes_provider.dart';
import '../../utils/constants.dart';
import '../widgets/tent_shape_selection_grid.dart';

class TentCreationScreen extends ConsumerStatefulWidget {
  const TentCreationScreen({super.key});

  @override
  ConsumerState<TentCreationScreen> createState() => _TentCreationScreenState();
}

class _TentCreationScreenState extends ConsumerState<TentCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();
  final _commentsController = TextEditingController();

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(tentCreationProvider);
    _nameController.text = draft.name;
    _sizeController.text = draft.sizeInput;
    _commentsController.text = draft.comments;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shapesState = ref.watch(tentShapesProvider);
    final creationState = ref.watch(tentCreationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer une tente')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _currentStep == 0
              ? _buildShapeStep(context, shapesState, creationState)
              : _buildDetailsStep(context, creationState),
        ),
      ),
    );
  }

  Widget _buildShapeStep(
    BuildContext context,
    AsyncValue<List<TentShape>> shapesState,
    TentCreationState creationState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Étape 1 : choisissez une forme',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: shapesState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ShapesErrorView(
              onRetry: () {
                ref.read(tentShapesProvider.notifier).retry();
              },
            ),
            data: (shapes) {
              if (shapes.isEmpty) {
                return const _ShapesEmptyView();
              }

              return TentShapeSelectionGrid(
                shapes: shapes,
                selectedShape: creationState.selectedShape,
                onSelect: (shape) {
                  ref.read(tentCreationProvider.notifier).selectShape(shape);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: creationState.selectedShape == null
              ? null
              : () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
          child: const Text('Continuer'),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(
    BuildContext context,
    TentCreationState creationState,
  ) {
    final notifier = ref.read(tentCreationProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            title: const Text('Forme sélectionnée'),
            subtitle: Text(creationState.selectedShape?.name ?? ''),
            trailing: TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                });
              },
              child: const Text('Modifier'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  key: const ValueKey('tent-name-input'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  maxLength: ValidationConstants.tentNameMaxLength,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: notifier.validateName,
                  onChanged: notifier.updateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('tent-size-input'),
                  controller: _sizeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Taille *'),
                  validator: notifier.validateSize,
                  onChanged: notifier.updateSize,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TentOverallState>(
                  key: const ValueKey('tent-overall-state-input'),
                  initialValue: creationState.overallState,
                  items: const [
                    DropdownMenuItem(
                      value: TentOverallState.good,
                      child: Text('Bon état'),
                    ),
                    DropdownMenuItem(
                      value: TentOverallState.needsRepair,
                      child: Text('À réparer'),
                    ),
                    DropdownMenuItem(
                      value: TentOverallState.unusable,
                      child: Text('Inutilisable'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateOverallState(value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'État global'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('tent-comments-input'),
                  controller: _commentsController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: ValidationConstants.tentCommentsMaxLength,
                  decoration: const InputDecoration(labelText: 'Commentaires'),
                  validator: notifier.validateComments,
                  onChanged: notifier.updateComments,
                ),
                if (creationState.submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    creationState.submitError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: creationState.isSubmitting
              ? null
              : () => _submit(notifier),
          child: creationState.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _submit(TentCreationNotifier notifier) async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final createdTent = await notifier.submit();
    if (!mounted || createdTent == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tente créée avec succès')));

    Navigator.of(context).pop<Tent>(createdTent);
  }
}

class _ShapesEmptyView extends StatelessWidget {
  const _ShapesEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Aucune forme de tente disponible pour le moment.'),
    );
  }
}

class _ShapesErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ShapesErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Impossible de charger les formes de tentes.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
