import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/design_constants.dart';
import '../../utils/form_autovalidate.dart';
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

  final _autovalidate = FormAutovalidate();
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
                        const Center(child: AppProgressIndicator()),
                    error: (_, _) => _buildModelsError(),
                    data: (models) => models.isEmpty
                        ? _buildModelsEmpty()
                        : _buildForm(models, creationState),
                  ),
                ),
                _buildBottomBar(creationState),
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

  Widget _buildForm(List<TentModel> models, TentCreationState creationState) {
    final notifier = ref.read(tentCreationProvider.notifier);

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
              autovalidateMode: _autovalidate.mode,
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
                    _buildDualColumn(creationState, notifier)
                  else
                    _buildSingleColumn(creationState, notifier),
                  _buildStateSegment(creationState, notifier),
                  const SizedBox(height: AppSpacing.md),
                  _buildCommentsField(creationState, notifier),
                  if (creationState.submitError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
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
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildModelDropdown(
    List<TentModel> models,
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return ModelSelectDropdown(
      key: const ValueKey('tent-model-dropdown'),
      models: models,
      selectedModel: creationState.selectedModel,
      onSelect: notifier.selectModel,
    );
  }

  Widget _buildDualColumn(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildNameField(creationState, notifier)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildSizeField(creationState, notifier)),
      ],
    );
  }

  Widget _buildSingleColumn(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Nom', required: true),
        const SizedBox(height: 6),
        TextFormField(
          key: const ValueKey('tent-name-input'),
          controller: _nameController,
          textInputAction: TextInputAction.next,
          maxLength: ValidationConstants.tentNameMaxLength,
          decoration:
              _textInputDecoration(hintText: 'ex: Tente #42 — Arizona Pro'),
          validator: notifier.validateName,
          onChanged: notifier.updateName,
        ),
        const SizedBox(height: 4),
        _buildCharCounter(
          _nameController.text.length,
          ValidationConstants.tentNameMaxLength,
        ),
      ],
    );
  }

  Widget _buildSizeField(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    int tryParse(String s) {
      final parsed = int.tryParse(s);
      return parsed ?? 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Taille (places)', required: true),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('tent-size-input'),
                controller: _sizeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _textInputDecoration().copyWith(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                validator: notifier.validateSize,
                onChanged: notifier.updateSize,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _StepperButton(
              icon: Icons.remove,
              onTap: () {
                final next =
                    (tryParse(_sizeController.text) - 1).clamp(1, 100);
                _sizeController.text = next.toString();
                notifier.updateSize(next.toString());
              },
            ),
            const SizedBox(width: AppSpacing.xs),
            _StepperButton(
              icon: Icons.add,
              onTap: () {
                final next =
                    (tryParse(_sizeController.text) + 1).clamp(1, 100);
                _sizeController.text = next.toString();
                notifier.updateSize(next.toString());
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStateSegment(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors =
        Theme.of(context).extension<AppSemanticColors>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('État global'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: colorScheme.onSurface.withAlpha(13),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              _StateSegBtn(
                label: 'Bon état',
                dotColor: semanticColors?.statePerfect ??
                    AppColors.statePerfect,
                isSelected:
                    creationState.overallState == TentOverallState.good,
                onTap: () =>
                    notifier.updateOverallState(TentOverallState.good),
              ),
              _StateSegBtn(
                label: 'À réparer',
                dotColor: semanticColors?.stateUsable ??
                    AppColors.stateUsable,
                isSelected: creationState.overallState ==
                    TentOverallState.needsRepair,
                onTap: () => notifier
                    .updateOverallState(TentOverallState.needsRepair),
              ),
              _StateSegBtn(
                label: 'Inutilisable',
                dotColor: semanticColors?.stateUnusable ??
                    AppColors.stateUnusable,
                isSelected: creationState.overallState ==
                    TentOverallState.unusable,
                onTap: () => notifier
                    .updateOverallState(TentOverallState.unusable),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsField(
    TentCreationState creationState,
    TentCreationNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Commentaires'),
        const SizedBox(height: 6),
        TextFormField(
          key: const ValueKey('tent-comments-input'),
          controller: _commentsController,
          minLines: 3,
          maxLines: 5,
          maxLength: ValidationConstants.tentCommentsMaxLength,
          decoration:
              _textInputDecoration(hintText: 'Notes, historique, remarques…'),
          validator: notifier.validateComments,
          onChanged: notifier.updateComments,
        ),
        const SizedBox(height: 4),
        _buildCharCounter(
          _commentsController.text.length,
          ValidationConstants.tentCommentsMaxLength,
        ),
      ],
    );
  }


  Widget _buildCharCounter(int current, int max) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$current / $max',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  InputDecoration _textInputDecoration({String? hintText}) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hintText,
      filled: false,
      fillColor: Colors.transparent,
      counterText: '',
      isDense: false,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
    );
  }

  Widget _buildBottomBar(TentCreationState creationState) {
    final colorScheme = Theme.of(context).colorScheme;
    final isValid = _isFormComplete(creationState);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withAlpha(247),
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: 14,
            bottom: 14,
          ),
          child: Center(
            child: SizedBox(
              width: 200,
              child: PrimarySubmitButton(
                label: 'Cr\u00e9er la tente',
                icon: Icons.add,
                isLoading: creationState.isSubmitting,
                enabled: isValid,
                onPressed: () => _submit(
                  ref.read(tentCreationProvider.notifier),
                ),
              ),
            ),
          ),
        ),
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

  bool _isFormComplete(TentCreationState state) {
    if (state.selectedModel == null) return false;
    if (state.name.trim().isEmpty) return false;
    final size = int.tryParse(state.sizeInput);
    if (size == null || size < 1 || size > 100) return false;
    return true;
  }

  Future<void> _submit(TentCreationNotifier notifier) async {
    if (_autovalidate.markAttempted()) setState(() {});

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

class _StateSegBtn extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StateSegBtn({
    required this.label,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.shadow.withAlpha(13),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

}
