import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../repositories/tent_repository.dart';
import 'tent_detail_provider.dart';
import 'tent_list_provider.dart';

part 'tent_edit_provider.g.dart';

enum EditableField { name, size, overallState, comments }

@riverpod
class TentEditNotifier extends _$TentEditNotifier {
  @override
  TentEditState build() => const TentEditState();

  Future<void> updateField({
    required String tentId,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
  }) async {
    state = state.copyWith(
      savingField: _determineSavingField(
        state.editingField,
        name: name,
        size: size,
        overallState: overallState,
        comments: comments,
        baseTent: state.baseTent,
      ),
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
          );

      ref.invalidate(tentDetailProvider(tentId));
      ref.read(tentListProvider.notifier).showTent(updatedTent);

      state = state.copyWith(
        baseTent: updatedTent,
        editingField: null,
        savingField: null,
        fieldError: null,
      );
    } on TentRepositoryException catch (e) {
      state = state.copyWith(savingField: null, fieldError: e.message);
    } catch (_) {
      state = state.copyWith(
        savingField: null,
        fieldError: 'Impossible de mettre à jour la tente. Réessayez.',
      );
    }
  }

  void startEditing(EditableField field, Tent tent) {
    state = state.copyWith(
      editingField: field,
      baseTent: tent,
      savingField: null,
      fieldError: null,
    );
  }

  void cancelEditing() {
    state = state.copyWith(
      editingField: null,
      savingField: null,
      fieldError: null,
    );
  }

  void clearError() {
    state = state.copyWith(fieldError: null);
  }

  EditableField? _determineSavingField(
    EditableField? editingField, {
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    Tent? baseTent,
  }) {
    if (baseTent == null) return editingField;

    if (baseTent.name != name) return EditableField.name;
    if (baseTent.size != size) return EditableField.size;
    if (baseTent.overallState != overallState) {
      return EditableField.overallState;
    }
    if (baseTent.comments != comments) return EditableField.comments;

    return editingField;
  }
}

class TentEditState {
  final EditableField? editingField;
  final EditableField? savingField;
  final Tent? baseTent;
  final String? fieldError;

  const TentEditState({
    this.editingField,
    this.savingField,
    this.baseTent,
    this.fieldError,
  });

  TentEditState copyWith({
    EditableField? editingField,
    EditableField? savingField,
    Tent? baseTent,
    String? fieldError,
    bool clearEditingField = false,
    bool clearSavingField = false,
    bool clearBaseTent = false,
    bool clearFieldError = false,
  }) {
    return TentEditState(
      editingField: clearEditingField
          ? null
          : editingField ?? this.editingField,
      savingField: clearSavingField ? null : savingField ?? this.savingField,
      baseTent: clearBaseTent ? null : baseTent ?? this.baseTent,
      fieldError: clearFieldError ? null : fieldError ?? this.fieldError,
    );
  }
}
