import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/part_kind.dart';
import '../repositories/tent_repository.dart';
import 'success_indicator_provider.dart';
import 'tent_detail_provider.dart';

part 'part_management_provider.g.dart';

@riverpod
class PartManagementNotifier extends _$PartManagementNotifier {
  @override
  PartManagementState build(String tentId) => const PartManagementState();

  Future<List<PartKind>> loadPartKinds() async {
    state = state.copyWith(isLoadingPartKinds: true, partKindsError: null);
    try {
      final kinds = await ref.read(tentRepositoryProvider).getPartKinds();
      state = state.copyWith(isLoadingPartKinds: false, partKinds: kinds);
      return kinds;
    } catch (e) {
      final message = e is TentRepositoryException
          ? e.message
          : 'Impossible de charger les types de pièces.';
      state = state.copyWith(
        isLoadingPartKinds: false,
        partKindsError: message,
      );
      return [];
    }
  }

  Future<bool> addParts(List<String> partKindIds) async {
    if (partKindIds.isEmpty) return false;

    state = state.copyWith(isAdding: true, addError: null);
    try {
      await ref
          .read(tentRepositoryProvider)
          .addPartsToTent(tentId: tentId, partKindIds: partKindIds);

      ref.invalidate(tentDetailProvider(tentId));
      ref.read(successIndicatorProvider.notifier).fire();
      state = state.copyWith(isAdding: false);
      return true;
    } on TentRepositoryException catch (e) {
      state = state.copyWith(isAdding: false, addError: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isAdding: false,
        addError: 'Impossible d\'ajouter les pièces. Réessayez.',
      );
      return false;
    }
  }

  Future<bool> removePart(String partId) async {
    state = state.copyWith(
      removingPartIds: {...state.removingPartIds, partId},
      removeError: null,
    );
    try {
      await ref.read(tentRepositoryProvider).removePart(partId: partId);

      ref.invalidate(tentDetailProvider(tentId));
      ref.read(successIndicatorProvider.notifier).fire();
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
      );
      return true;
    } on TentRepositoryException catch (e) {
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
        removeError: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
        removeError: 'Impossible de supprimer la pièce. Réessayez.',
      );
      return false;
    }
  }

  void clearAddError() {
    state = state.copyWith(addError: null);
  }

  void clearRemoveError() {
    state = state.copyWith(removeError: null);
  }
}

class PartManagementState {
  final List<PartKind> partKinds;
  final bool isLoadingPartKinds;
  final String? partKindsError;
  final bool isAdding;
  final String? addError;
  final Set<String> removingPartIds;
  final String? removeError;

  const PartManagementState({
    this.partKinds = const [],
    this.isLoadingPartKinds = false,
    this.partKindsError,
    this.isAdding = false,
    this.addError,
    this.removingPartIds = const {},
    this.removeError,
  });

  PartManagementState copyWith({
    List<PartKind>? partKinds,
    bool? isLoadingPartKinds,
    String? partKindsError,
    bool? isAdding,
    String? addError,
    Set<String>? removingPartIds,
    String? removeError,
    bool clearPartKindsError = false,
    bool clearAddError = false,
    bool clearRemoveError = false,
  }) {
    return PartManagementState(
      partKinds: partKinds ?? this.partKinds,
      isLoadingPartKinds: isLoadingPartKinds ?? this.isLoadingPartKinds,
      partKindsError: clearPartKindsError
          ? null
          : partKindsError ?? this.partKindsError,
      isAdding: isAdding ?? this.isAdding,
      addError: clearAddError ? null : addError ?? this.addError,
      removingPartIds: removingPartIds ?? this.removingPartIds,
      removeError: clearRemoveError ? null : removeError ?? this.removeError,
    );
  }
}
