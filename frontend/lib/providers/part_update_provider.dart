import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/part.dart';
import '../repositories/tent_repository.dart';
import 'tent_detail_provider.dart';

part 'part_update_provider.g.dart';

@riverpod
class PartUpdateNotifier extends _$PartUpdateNotifier {
  @override
  PartUpdateState build(String tentId) => const PartUpdateState();

  Future<void> updatePartState({
    required String partId,
    required PartState previousState,
    required PartState newState,
  }) async {
    final requestVersion = (state.requestVersions[partId] ?? 0) + 1;
    final nextVersions = Map<String, int>.from(state.requestVersions)
      ..[partId] = requestVersion;
    final nextPending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
      ..[partId] = PendingPartUpdate(
        previousState: previousState,
        selectedState: newState,
        requestVersion: requestVersion,
      );
    final nextErrors = Map<String, String>.from(state.errors)..remove(partId);
    final nextFailed = Map<String, PendingPartUpdate>.from(
      state.lastFailedRequests,
    )..remove(partId);

    state = state.copyWith(
      pendingUpdates: nextPending,
      requestVersions: nextVersions,
      errors: nextErrors,
      lastFailedRequests: nextFailed,
    );

    try {
      final updatedPart = await ref
          .read(tentRepositoryProvider)
          .updatePartState(id: partId, state: newState);
      if (!ref.mounted) {
        return;
      }

      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return;
      }

      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..[partId] = updatedPart.state;
      final failed = Map<String, PendingPartUpdate>.from(
        state.lastFailedRequests,
      )..remove(partId);

      state = state.copyWith(
        pendingUpdates: pending,
        confirmedStates: confirmed,
        lastFailedRequests: failed,
      );

      ref.invalidate(tentDetailProvider(tentId));
    } on TentRepositoryException catch (e) {
      if (!ref.mounted) {
        return;
      }
      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return;
      }

      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final errors = Map<String, String>.from(state.errors)
        ..[partId] = e.message;
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..[partId] = previousState;
      final failed = Map<String, PendingPartUpdate>.from(
        state.lastFailedRequests,
      )..[partId] = PendingPartUpdate(
          previousState: previousState,
          selectedState: newState,
          requestVersion: requestVersion,
        );

      state = state.copyWith(
        pendingUpdates: pending,
        errors: errors,
        confirmedStates: confirmed,
        lastFailedRequests: failed,
      );
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return;
      }

      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final errors = Map<String, String>.from(state.errors)
        ..[partId] = 'Impossible de mettre à jour l\'élément. Réessayez.';
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..[partId] = previousState;
      final failed = Map<String, PendingPartUpdate>.from(
        state.lastFailedRequests,
      )..[partId] = PendingPartUpdate(
          previousState: previousState,
          selectedState: newState,
          requestVersion: requestVersion,
        );

      state = state.copyWith(
        pendingUpdates: pending,
        errors: errors,
        confirmedStates: confirmed,
        lastFailedRequests: failed,
      );
    }
  }

  Future<void> retry(String partId) async {
    final pending = state.lastFailedRequests[partId];
    if (pending == null) {
      return;
    }

    await updatePartState(
      partId: partId,
      previousState: pending.previousState,
      newState: pending.selectedState,
    );
  }

  PartState resolveDisplayedState(Part part) {
    final pending = state.pendingUpdates[part.id];
    if (pending != null) {
      return pending.selectedState;
    }

    return state.confirmedStates[part.id] ?? part.state;
  }

  bool isSaving(String partId) => state.pendingUpdates.containsKey(partId);

  String? errorFor(String partId) => state.errors[partId];

  PendingPartUpdate? failedRequestFor(String partId) =>
      state.lastFailedRequests[partId];
}

class PartUpdateState {
  final Map<String, PendingPartUpdate> pendingUpdates;
  final Map<String, int> requestVersions;
  final Map<String, String> errors;
  final Map<String, PartState> confirmedStates;
  final Map<String, PendingPartUpdate> lastFailedRequests;

  const PartUpdateState({
    this.pendingUpdates = const {},
    this.requestVersions = const {},
    this.errors = const {},
    this.confirmedStates = const {},
    this.lastFailedRequests = const {},
  });

  PartUpdateState copyWith({
    Map<String, PendingPartUpdate>? pendingUpdates,
    Map<String, int>? requestVersions,
    Map<String, String>? errors,
    Map<String, PartState>? confirmedStates,
    Map<String, PendingPartUpdate>? lastFailedRequests,
  }) {
    return PartUpdateState(
      pendingUpdates: pendingUpdates ?? this.pendingUpdates,
      requestVersions: requestVersions ?? this.requestVersions,
      errors: errors ?? this.errors,
      confirmedStates: confirmedStates ?? this.confirmedStates,
      lastFailedRequests: lastFailedRequests ?? this.lastFailedRequests,
    );
  }
}

class PendingPartUpdate {
  final PartState previousState;
  final PartState selectedState;
  final int requestVersion;

  const PendingPartUpdate({
    required this.previousState,
    required this.selectedState,
    required this.requestVersion,
  });
}
