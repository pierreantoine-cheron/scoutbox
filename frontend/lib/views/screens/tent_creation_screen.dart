import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class TentCreationScreen extends ConsumerStatefulWidget {
  const TentCreationScreen({super.key});

  @override
  ConsumerState<TentCreationScreen> createState() => _TentCreationScreenState();
}

class _TentCreationScreenState extends ConsumerState<TentCreationScreen>
    with RouteAware, RouteAwareAppBarMixin<TentCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();
  final _commentsController = TextEditingController();

  int _currentStep = 0;
  bool _didAttemptSubmit = false;
  bool _isRetryingModels = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(tentCreationProvider);
    _nameController.text = draft.name;
    _sizeController.text = draft.sizeInput;
    _commentsController.text = draft.comments;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscribeRouteObserver();
    dispatchAppBarConfig();
  }

  @override
  void dispose() {
    unsubscribeRouteObserver();
    _nameController.dispose();
    _sizeController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    dispatchAppBarConfig();
  }

  @override
  AppBarConfig buildAppBarConfig() {
    if (!mounted) return const AppBarConfig(screenId: '');

    return const AppBarConfig(
      screenId: 'tent_creation',
      title: Text('Créer une tente'),
      showBackButton: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsState = ref.watch(tentModelsProvider);
    final creationState = ref.watch(tentCreationProvider);
    _syncControllersFromState(creationState);

    return Material(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }

          final shouldLeave = await _confirmDiscardDraft();
          if (shouldLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _currentStep == 0
                  ? _buildModelStep(context, modelsState, creationState)
                  : _buildDetailsStep(context, creationState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelStep(
    BuildContext context,
    AsyncValue<List<TentModel>> modelsState,
    TentCreationState creationState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Étape 1 : choisissez un modèle',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: modelsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => AsyncErrorView(
              message: 'Impossible de charger les modèles de tentes.',
              isRetrying: _isRetryingModels,
              onRetry: _retryModels,
            ),
            data: (models) {
              if (models.isEmpty) {
                return const _ModelsEmptyView();
              }

              return TentModelSelectionGrid(
                models: models,
                selectedModel: creationState.selectedModel,
                onSelect: (model) {
                  ref.read(tentCreationProvider.notifier).selectModel(model);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: creationState.selectedModel == null
              ? null
              : () => _goToDetailsStep(),
          child: const Text('Continuer'),
        ),
        if (creationState.submitError != null) ...[
          const SizedBox(height: 8),
          Text(
            creationState.submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
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
            title: const Text('Modèle sélectionné'),
            subtitle: Text(creationState.selectedModel?.name ?? ''),
            trailing: TextButton(
              onPressed: _goToModelStep,
              child: const Text('Modifier'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Form(
            key: _formKey,
            autovalidateMode: _didAttemptSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
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
    if (!_didAttemptSubmit) {
      setState(() {
        _didAttemptSubmit = true;
      });
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final createdTent = await notifier.submit();
    if (!mounted || createdTent == null) {
      return;
    }

    Navigator.of(context).pop<Tent>(createdTent);
  }

  void _syncControllersFromState(TentCreationState creationState) {
    _syncController(_nameController, creationState.name);
    _syncController(_sizeController, creationState.sizeInput);
    _syncController(_commentsController, creationState.comments);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _goToDetailsStep() {
    ref.read(tentCreationProvider.notifier).clearSubmitError();
    setState(() {
      _currentStep = 1;
    });
  }

  void _goToModelStep() {
    FocusScope.of(context).unfocus();
    ref.read(tentCreationProvider.notifier).clearSubmitError();
    setState(() {
      _currentStep = 0;
    });
  }

  Future<void> _retryModels() async {
    if (_isRetryingModels) {
      return;
    }

    setState(() {
      _isRetryingModels = true;
    });

    await ref.read(tentModelsProvider.notifier).retry();
    if (!mounted) {
      return;
    }

    setState(() {
      _isRetryingModels = false;
    });
  }

  Future<bool> _confirmDiscardDraft() async {
    return showConfirmDialog(
      context,
      title: 'Quitter la création ?',
      content: 'Votre brouillon sera conservé pour plus tard.',
      confirmLabel: 'Quitter',
      cancelLabel: 'Rester',
    );
  }
}

class _ModelsEmptyView extends StatelessWidget {
  const _ModelsEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Aucun modèle de tente disponible pour le moment.'),
    );
  }
}
