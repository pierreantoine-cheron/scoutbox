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
    state = state.copyWith(isLoadingPartKinds: true, clearPartKindsError: true);
    try {
      final kinds = await ref.read(tentRepositoryProvider).getPartKinds();
      if (!ref.mounted) return kinds;
      state = state.copyWith(isLoadingPartKinds: false, partKinds: kinds);
      return kinds;
    } catch (e) {
      if (!ref.mounted) return [];
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

    final requestVersion = state.requestVersion + 1;
    state = state.copyWith(
      isAdding: true,
      requestVersion: requestVersion,
      clearAddError: true,
    );
    try {
      await ref
          .read(tentRepositoryProvider)
          .addPartsToTent(tentId: tentId, partKindIds: partKindIds);
      if (!ref.mounted || state.requestVersion != requestVersion) return false;

      ref.invalidate(tentDetailProvider(tentId));
      ref.read(successIndicatorProvider.notifier).fire();
      state = state.copyWith(isAdding: false);
      return true;
    } on TentRepositoryException catch (e) {
      if (!ref.mounted || state.requestVersion != requestVersion) return false;
      state = state.copyWith(isAdding: false, addError: e.message);
      return false;
    } catch (_) {
      if (!ref.mounted || state.requestVersion != requestVersion) return false;
      state = state.copyWith(
        isAdding: false,
        addError: 'Impossible d\'ajouter les pièces. Réessayez.',
      );
      return false;
    }
  }

  Future<bool> removePart(String partId) async {
    final requestVersion = state.requestVersion + 1;
    state = state.copyWith(
      requestVersion: requestVersion,
      removingPartIds: {...state.removingPartIds, partId},
      clearRemoveError: true,
    );
    try {
      await ref.read(tentRepositoryProvider).removePart(partId: partId);
      if (!ref.mounted || state.requestVersion != requestVersion) return false;

      ref.invalidate(tentDetailProvider(tentId));
      ref.read(successIndicatorProvider.notifier).fire();
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
      );
      return true;
    } on TentRepositoryException catch (e) {
      if (!ref.mounted || state.requestVersion != requestVersion) return false;
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
        removeError: e.message,
      );
      return false;
    } catch (_) {
      if (!ref.mounted || state.requestVersion != requestVersion) return false;
      state = state.copyWith(
        removingPartIds: {...state.removingPartIds}..remove(partId),
        removeError: 'Impossible de supprimer la pièce. Réessayez.',
      );
      return false;
    }
  }

  void clearAddError() {
    state = state.copyWith(clearAddError: true);
  }

  void clearRemoveError() {
    state = state.copyWith(clearRemoveError: true);
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
  final int requestVersion;

  const PartManagementState({
    this.partKinds = const [],
    this.isLoadingPartKinds = false,
    this.partKindsError,
    this.isAdding = false,
    this.addError,
    this.removingPartIds = const {},
    this.removeError,
    this.requestVersion = 0,
  });

  PartManagementState copyWith({
    List<PartKind>? partKinds,
    bool? isLoadingPartKinds,
    String? partKindsError,
    bool? isAdding,
    String? addError,
    Set<String>? removingPartIds,
    String? removeError,
    int? requestVersion,
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
      requestVersion: requestVersion ?? this.requestVersion,
    );
  }
}
