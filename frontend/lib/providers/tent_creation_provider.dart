import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../repositories/tent_repository.dart';
import '../services/error_localizer.dart';
import '../utils/constants.dart';

part 'tent_creation_provider.g.dart';

@riverpod
class TentCreationNotifier extends _$TentCreationNotifier {
  @override
  TentCreationState build() {
    return const TentCreationState();
  }

  void selectShape(TentShape shape) {
    state = state.copyWith(selectedShape: shape, submitError: null);
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

  String? validateName(String? value) {
    if (value == null) {
      return 'Le nom de la tente est requis';
    }

    if (value.trim().isEmpty) {
      return 'Le nom de la tente est requis';
    }

    if (value.trim().length > ValidationConstants.tentNameMaxLength) {
      return 'Le nom ne doit pas dépasser 100 caractères';
    }

    return null;
  }

  String? validateSize(String? value) {
    if (value == null) {
      return 'La taille doit être un nombre positif';
    }

    if (value.trim().isEmpty) {
      return 'La taille doit être un nombre positif';
    }

    final parsedSize = int.tryParse(value);
    if (parsedSize == null ||
        parsedSize < ValidationConstants.tentMinSize ||
        parsedSize > ValidationConstants.tentMaxSize) {
      return 'La taille doit être un nombre positif';
    }

    return null;
  }

  String? validateComments(String? value) {
    if (value == null) {
      return null;
    }
    if (value.length > ValidationConstants.tentCommentsMaxLength) {
      return 'Le commentaire ne doit pas dépasser 500 caractères';
    }

    return null;
  }

  Future<Tent?> submit() async {
    if (state.selectedShape == null) {
      state = state.copyWith(
        submitError: 'Veuillez sélectionner une forme de tente',
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
        tentShapeId: state.selectedShape!.id,
        overallState: state.overallState,
        comments: state.comments.trim().isEmpty ? null : state.comments.trim(),
      );

      state = state.copyWith(isSubmitting: false);
      return createdTent;
    } on TentRepositoryException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: ErrorLocalizer.localize(e.code),
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
  final TentShape? selectedShape;
  final String name;
  final String sizeInput;
  final TentOverallState overallState;
  final String comments;
  final bool isSubmitting;
  final String? submitError;

  const TentCreationState({
    this.selectedShape,
    this.name = '',
    this.sizeInput = '',
    this.overallState = TentOverallState.good,
    this.comments = '',
    this.isSubmitting = false,
    this.submitError,
  });

  TentCreationState copyWith({
    TentShape? selectedShape,
    String? name,
    String? sizeInput,
    TentOverallState? overallState,
    String? comments,
    bool? isSubmitting,
    String? submitError,
    bool clearSelectedShape = false,
  }) {
    return TentCreationState(
      selectedShape: clearSelectedShape
          ? null
          : (selectedShape ?? this.selectedShape),
      name: name ?? this.name,
      sizeInput: sizeInput ?? this.sizeInput,
      overallState: overallState ?? this.overallState,
      comments: comments ?? this.comments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
    );
  }
}
