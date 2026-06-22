import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../repositories/tent_repository.dart';
import '../services/error_localizer.dart';
import '../utils/tent_validators.dart';
import 'tent_models_provider.dart';

part 'tent_creation_provider.g.dart';

@riverpod
class TentCreationNotifier extends _$TentCreationNotifier {
  @override
  TentCreationState build() {
    return const TentCreationState();
  }

  void selectModel(TentModel model) {
    state = state.copyWith(selectedModel: model, submitError: null);
  }

  void updateName(String value) {
    state = state.copyWith(name: value, submitError: null);
  }

  void updateSize(String value) {
    state = state.copyWith(sizeInput: value, submitError: null);
  }

  void updateOverallState(TentOverallState value) {
    state = state.copyWith(overallState: value, submitError: null);
  }

  void updateComments(String value) {
    state = state.copyWith(comments: value, submitError: null);
  }

  void clearSubmitError() {
    state = state.copyWith(submitError: null);
  }

  String? validateName(String? value) => TentValidators.validateName(value);

  String? validateSize(String? value) => TentValidators.validateSize(value);

  String? validateComments(String? value) => TentValidators.validateComments(value);

  Future<Tent?> submit() async {
    if (state.selectedModel == null) {
      state = state.copyWith(
        submitError: 'Veuillez sélectionner un modèle de tente',
      );
      return null;
    }

    final nameError = validateName(state.name);
    if (nameError != null) {
      state = state.copyWith(submitError: nameError);
      return null;
    }

    final sizeError = validateSize(state.sizeInput);
    if (sizeError != null) {
      state = state.copyWith(submitError: sizeError);
      return null;
    }

    final commentsError = validateComments(state.comments);
    if (commentsError != null) {
      state = state.copyWith(submitError: commentsError);
      return null;
    }

    state = state.copyWith(isSubmitting: true, submitError: null);

    try {
      final repository = ref.read(tentRepositoryProvider);
      final createdTent = await repository.createTent(
        name: state.name.trim(),
        size: int.parse(state.sizeInput),
        tentModelId: state.selectedModel!.id,
        overallState: state.overallState,
        comments: state.comments.trim().isEmpty ? null : state.comments.trim(),
      );

      ref.invalidate(tentModelsProvider);

      state = state.copyWith(isSubmitting: false);
      return createdTent;
    } on TentRepositoryException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: ErrorLocalizer.localize(e.code, fallback: e.message),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Erreur serveur. Réessayez.',
      );
      return null;
    }
  }
}

class TentCreationState {
  final TentModel? selectedModel;
  final String name;
  final String sizeInput;
  final TentOverallState overallState;
  final String comments;
  final bool isSubmitting;
  final String? submitError;

  const TentCreationState({
    this.selectedModel,
    this.name = '',
    this.sizeInput = '',
    this.overallState = TentOverallState.good,
    this.comments = '',
    this.isSubmitting = false,
    this.submitError,
  });

  TentCreationState copyWith({
    TentModel? selectedModel,
    String? name,
    String? sizeInput,
    TentOverallState? overallState,
    String? comments,
    bool? isSubmitting,
    String? submitError,
    bool clearSelectedModel = false,
  }) {
    return TentCreationState(
      selectedModel: clearSelectedModel ? null : (selectedModel ?? this.selectedModel),
      name: name ?? this.name,
      sizeInput: sizeInput ?? this.sizeInput,
      overallState: overallState ?? this.overallState,
      comments: comments ?? this.comments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
    );
  }
}
