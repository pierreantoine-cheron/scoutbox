import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';
import '../services/error_localizer.dart';
import 'tent_detail_provider.dart';
import 'tent_history_provider.dart';
import 'tent_list_provider.dart';

part 'tent_edit_provider.g.dart';

enum EditableField { name, size, overallState, comments, model }

@riverpod
class TentEditNotifier extends _$TentEditNotifier {
  @override
  TentEditState build(String tentId) => const TentEditState();

  Future<void> updateField({
    required String tentId,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
  }) async {
    final retryRequest = PendingTentUpdate(
      tentId: tentId,
      name: name,
      size: size,
      overallState: overallState,
      comments: comments,
      tentModelId: tentModelId,
    );

    state = state.copyWith(
      savingField: _determineSavingField(
        state.editingField,
        name: name,
        size: size,
        overallState: overallState,
        comments: comments,
        tentModelId: tentModelId,
        baseTent: state.baseTent,
      ),
      pendingRetry: retryRequest,
      clearFieldError: true,
    );

    try {
      final updatedTent = await ref
          .read(tentRepositoryProvider)
          .updateTent(
            id: tentId,
            name: name,
            size: size,
            overallState: overallState,
            comments: comments,
            tentModelId: tentModelId,
          );

      ref.invalidate(tentDetailProvider(tentId));
      invalidateTentHistory(ref, tentId);
      ref.read(tentListProvider.notifier).showTent(updatedTent);

      state = state.copyWith(
        baseTent: updatedTent,
        lastSaveTime: DateTime.now(),
        clearEditingField: true,
        clearSavingField: true,
        clearFieldError: true,
        clearPendingRetry: true,
      );
    } on TentRepositoryException catch (e) {
      state = state.copyWith(
        fieldError: ErrorLocalizer.localize(e.code, fallback: e.message),
        clearSavingField: true,
        pendingRetry: retryRequest,
      );
    } catch (_) {
      state = state.copyWith(
        fieldError: 'Impossible de mettre à jour la tente. Réessayez.',
        clearSavingField: true,
        pendingRetry: retryRequest,
      );
    }
  }

  Future<void> updateModel({
    required String tentId,
    required String tentModelId,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
  }) async {
    await updateField(
      tentId: tentId,
      name: name,
      size: size,
      overallState: overallState,
      comments: comments,
      tentModelId: tentModelId,
    );
  }

  Future<void> retryLastUpdate() async {
    final request = state.pendingRetry;
    if (request == null) return;

    await updateField(
      tentId: request.tentId,
      name: request.name,
      size: request.size,
      overallState: request.overallState,
      comments: request.comments,
      tentModelId: request.tentModelId,
    );
  }

  void startEditing(EditableField field, Tent tent) {
    state = state.copyWith(
      editingField: field,
      baseTent: tent,
      clearSavingField: true,
      clearFieldError: true,
      clearPendingRetry: true,
    );
  }

  void cancelEditing() {
    state = state.copyWith(
      clearEditingField: true,
      clearSavingField: true,
      clearFieldError: true,
      clearPendingRetry: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearFieldError: true);
  }

  EditableField? _determineSavingField(
    EditableField? editingField, {
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
    Tent? baseTent,
  }) {
    if (baseTent == null) return editingField;

    if (baseTent.name != name) return EditableField.name;
    if (baseTent.size != size) return EditableField.size;
    if (baseTent.overallState != overallState) {
      return EditableField.overallState;
    }
    if (baseTent.comments != comments) return EditableField.comments;
    if (tentModelId != null && baseTent.tentModelId != tentModelId) {
      return EditableField.model;
    }

    return editingField;
  }
}

class TentEditState {
  final EditableField? editingField;
  final EditableField? savingField;
  final Tent? baseTent;
  final String? fieldError;
  final PendingTentUpdate? pendingRetry;
  final DateTime? lastSaveTime;

  const TentEditState({
    this.editingField,
    this.savingField,
    this.baseTent,
    this.fieldError,
    this.pendingRetry,
    this.lastSaveTime,
  });

  TentEditState copyWith({
    EditableField? editingField,
    EditableField? savingField,
    Tent? baseTent,
    String? fieldError,
    PendingTentUpdate? pendingRetry,
    DateTime? lastSaveTime,
    bool clearEditingField = false,
    bool clearSavingField = false,
    bool clearBaseTent = false,
    bool clearFieldError = false,
    bool clearPendingRetry = false,
  }) {
    return TentEditState(
      editingField: clearEditingField ? null : editingField ?? this.editingField,
      savingField: clearSavingField ? null : savingField ?? this.savingField,
      baseTent: clearBaseTent ? null : baseTent ?? this.baseTent,
      fieldError: clearFieldError ? null : fieldError ?? this.fieldError,
      pendingRetry: clearPendingRetry ? null : pendingRetry ?? this.pendingRetry,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
    );
  }
}

class PendingTentUpdate {
  final String tentId;
  final String name;
  final int size;
  final TentOverallState overallState;
  final String? comments;
  final String? tentModelId;

  const PendingTentUpdate({
    required this.tentId,
    required this.name,
    required this.size,
    required this.overallState,
    this.comments,
    this.tentModelId,
  });
}
