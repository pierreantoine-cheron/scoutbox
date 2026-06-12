import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/design_constants.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class TentCreationScreen extends ConsumerStatefulWidget {
  const TentCreationScreen({super.key});

  @override
  ConsumerState<TentCreationScreen> createState() =>
      _TentCreationScreenState();
}

class _TentCreationScreenState extends ConsumerState<TentCreationScreen>
    with RouteAware, RouteAwareAppBarMixin<TentCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();
  final _commentsController = TextEditingController();

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
      title: Text('Nouvelle tente'),
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
          if (didPop) return;
          final shouldLeave = await _confirmDiscardDraft();
          if (shouldLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: modelsState.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _buildModelsError(),
                    data: (models) => models.isEmpty
                        ? _buildModelsEmpty()
                        : _buildForm(context, creationState, models),
                  ),
                ),
                _buildBottomBar(context, creationState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelsError() {
    return AsyncErrorView(
      message: 'Impossible de charger les modèles de tentes.',
      isRetrying: _isRetryingModels,
      onRetry: _retryModels,
    );
  }

  Widget _buildModelsEmpty() {
    return const Center(
      child: Text('Aucun modèle de tente disponible pour le moment.'),
    );
  }

  Widget _buildForm(
    BuildContext context,
    TentCreationState creationState,
    List<TentModel> models,
  ) {
    final notifier = ref.read(tentCreationProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors =
        Theme.of(context).extension<AppSemanticColors>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDualColumn = constraints.maxWidth >= 550;

        return SingleChildScrollView(
          padding: _formPadding(constraints.maxWidth),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _formMaxWidth(constraints.maxWidth),
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: _didAttemptSubmit
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionLabel('Modèle'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildModelDropdown(models, creationState, notifier),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  if (isDualColumn)
                    _buildDualColumn(context, creationState, notifier)
                  else
                    _buildSingleColumn(context, creationState, notifier),
                  _buildStateSegment(
                    creationState,
                    notifier,
                    semanticColors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildCommentsField(creationState, notifier),
                  if (creationState.submitError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      creationState.submitError!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildModelDropdown(
    List<TentModel> models,
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return DropdownMenu<TentModel>(
      key: const ValueKey('tent-model-dropdown'),
      expandedInsets: EdgeInsets.zero,
      enableFilter: false,
      enableSearch: false,
      initialSelection: creationState.selectedModel,
      hintText: 'Choisir un modèle',
      inputDecorationTheme: Theme.of(context).inputDecorationTheme,
      menuStyle: MenuStyle(
        maximumSize: WidgetStateProperty.all(
          const Size.fromHeight(280),
        ),
      ),
      onSelected: (model) {
        if (model != null) notifier.selectModel(model);
      },
      dropdownMenuEntries: models.map((m) {
        return DropdownMenuEntry<TentModel>(
          value: m,
          label: m.name,
        );
      }).toList(),
    );
  }

  Widget _buildDualColumn(
    BuildContext context,
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildNameField(creationState, notifier),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildSizeField(creationState, notifier),
        ),
      ],
    );
  }

  Widget _buildSingleColumn(
    BuildContext context,
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNameField(creationState, notifier),
        const SizedBox(height: AppSpacing.md),
        _buildSizeField(creationState, notifier),
      ],
    );
  }

  Widget _buildNameField(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return TextFormField(
      key: const ValueKey('tent-name-input'),
      controller: _nameController,
      textInputAction: TextInputAction.next,
      maxLength: ValidationConstants.tentNameMaxLength,
      decoration: const InputDecoration(
        labelText: 'Nom *',
        hintText: 'ex: Tente #42 — Arizona Pro',
      ),
      validator: notifier.validateName,
      onChanged: notifier.updateName,
    );
  }

  Widget _buildSizeField(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return TextFormField(
      key: const ValueKey('tent-size-input'),
      controller: _sizeController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Taille (places) *',
        hintText: 'ex: 6',
      ),
      validator: notifier.validateSize,
      onChanged: notifier.updateSize,
    );
  }

  Widget _buildStateSegment(
    TentCreationState creationState,
    TentCreationNotifier notifier,
    AppSemanticColors? semanticColors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'État global',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<TentOverallState>(
          segments: [
            ButtonSegment<TentOverallState>(
              value: TentOverallState.good,
              label: const Text('Bon état'),
              icon: _stateDot(
                semanticColors?.statePerfect ?? AppColors.statePerfect,
              ),
            ),
            ButtonSegment<TentOverallState>(
              value: TentOverallState.needsRepair,
              label: const Text('À réparer'),
              icon: _stateDot(
                semanticColors?.stateUsable ?? AppColors.stateUsable,
              ),
            ),
            ButtonSegment<TentOverallState>(
              value: TentOverallState.unusable,
              label: const Text('Inutilisable'),
              icon: _stateDot(
                semanticColors?.stateUnusable ?? AppColors.stateUnusable,
              ),
            ),
          ],
          selected: {creationState.overallState},
          onSelectionChanged: (states) {
            if (states.isNotEmpty) {
              notifier.updateOverallState(states.first);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCommentsField(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return TextFormField(
      key: const ValueKey('tent-comments-input'),
      controller: _commentsController,
      minLines: 3,
      maxLines: 5,
      maxLength: ValidationConstants.tentCommentsMaxLength,
      decoration: const InputDecoration(
        labelText: 'Commentaires',
        hintText: 'Notes, historique, remarques…',
      ),
      validator: notifier.validateComments,
      onChanged: notifier.updateComments,
    );
  }

  Widget _buildBottomBar(BuildContext context, TentCreationState creationState) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(247),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: 14,
        bottom: 14,
      ),
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 48),
          ),
          onPressed: creationState.isSubmitting
              ? null
              : () => _submit(ref.read(tentCreationProvider.notifier)),
          icon: creationState.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surface,
                  ),
                )
              : const Icon(Icons.add, size: 18),
          label: const Text('Créer la tente'),
        ),
      ),
    );
  }

  Widget _stateDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  EdgeInsets _formPadding(double width) {
    if (width >= 900) {
      return const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        40,
        AppSpacing.xl,
        0,
      );
    } else if (width >= 600) {
      return const EdgeInsets.fromLTRB(AppSpacing.lg, 32, AppSpacing.lg, 0);
    } else {
      return const EdgeInsets.fromLTRB(AppSpacing.md, 20, AppSpacing.md, 0);
    }
  }

  double _formMaxWidth(double width) {
    if (width >= 900) return 720;
    if (width >= 600) return 640;
    return double.infinity;
  }

  Future<void> _submit(TentCreationNotifier notifier) async {
    if (!_didAttemptSubmit) {
      setState(() => _didAttemptSubmit = true);
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final createdTent = await notifier.submit();
    if (!mounted || createdTent == null) return;

    Navigator.of(context).pop<Tent>(createdTent);
  }

  void _syncControllersFromState(TentCreationState creationState) {
    _syncController(_nameController, creationState.name);
    _syncController(_sizeController, creationState.sizeInput);
    _syncController(_commentsController, creationState.comments);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _retryModels() async {
    if (_isRetryingModels) return;

    setState(() => _isRetryingModels = true);

    await ref.read(tentModelsProvider.notifier).retry();
    if (!mounted) return;

    setState(() => _isRetryingModels = false);
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
