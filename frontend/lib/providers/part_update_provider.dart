import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/part.dart';
import '../repositories/tent_repository.dart';
import '../services/error_localizer.dart';
import 'tent_detail_provider.dart';
import 'tent_history_provider.dart';

part 'part_update_provider.g.dart';

@riverpod
class PartUpdateNotifier extends _$PartUpdateNotifier {
  @override
  PartUpdateState build(String tentId) => const PartUpdateState();

  Future<PartUpdateResult> updatePartState({
    required String partId,
    required PartState previousState,
    required PartState newState,
    required String? previousComments,
    required String? newComments,
  }) async {
    final normalizedComments = _normalizeComments(newComments);
    final normalizedPreviousComments = _normalizeComments(previousComments);
    if (previousState == newState &&
        normalizedPreviousComments == normalizedComments) {
      return PartUpdateResult.noChange;
    }

    final requestVersion = (state.requestVersions[partId] ?? 0) + 1;
    final sourceState =
        state.pendingUpdates[partId]?.sourceState ??
        state.confirmedSourceStates[partId] ??
        previousState;
    final nextVersions = Map<String, int>.from(state.requestVersions)
      ..[partId] = requestVersion;
    final nextPending =
        Map<String, PendingPartUpdate>.from(state.pendingUpdates)
          ..[partId] = PendingPartUpdate(
            previousState: previousState,
            selectedState: newState,
            previousComments: normalizedPreviousComments,
            selectedComments: normalizedComments,
            requestVersion: requestVersion,
            sourceState: sourceState,
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
          .updatePartState(
            id: partId,
            state: newState,
            comments: normalizedComments,
          );
      if (!ref.mounted) {
        return PartUpdateResult.stale;
      }

      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return PartUpdateResult.stale;
      }

      final completedRequest = state.pendingUpdates[partId];
      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..[partId] = updatedPart.state;
      final confirmedSources = Map<String, PartState>.from(
        state.confirmedSourceStates,
      )..[partId] = completedRequest?.sourceState ?? previousState;
      final failed = Map<String, PendingPartUpdate>.from(
        state.lastFailedRequests,
      )..remove(partId);

      state = state.copyWith(
        pendingUpdates: pending,
        confirmedStates: confirmed,
        confirmedSourceStates: confirmedSources,
        lastFailedRequests: failed,
      );

      ref.invalidate(tentDetailProvider(tentId));
      invalidateTentHistory(ref, tentId);
      return PartUpdateResult.success;
    } on TentRepositoryException catch (e) {
      if (!ref.mounted) {
        return PartUpdateResult.stale;
      }
      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return PartUpdateResult.stale;
      }

      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final errors = Map<String, String>.from(state.errors)
        ..[partId] = ErrorLocalizer.localize(e.code, fallback: e.message);
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..remove(partId);
      final confirmedSources = Map<String, PartState>.from(
        state.confirmedSourceStates,
      )..remove(partId);
      final failed =
          Map<String, PendingPartUpdate>.from(state.lastFailedRequests)
            ..[partId] = PendingPartUpdate(
              previousState: previousState,
              selectedState: newState,
              previousComments: normalizedPreviousComments,
              selectedComments: normalizedComments,
              requestVersion: requestVersion,
              sourceState: sourceState,
            );

      state = state.copyWith(
        pendingUpdates: pending,
        errors: errors,
        confirmedStates: confirmed,
        confirmedSourceStates: confirmedSources,
        lastFailedRequests: failed,
      );
      return PartUpdateResult.failure;
    } catch (_) {
      if (!ref.mounted) {
        return PartUpdateResult.stale;
      }
      final latestVersion = state.requestVersions[partId];
      if (latestVersion != requestVersion) {
        return PartUpdateResult.stale;
      }

      final pending = Map<String, PendingPartUpdate>.from(state.pendingUpdates)
        ..remove(partId);
      final errors = Map<String, String>.from(state.errors)
        ..[partId] = 'Impossible de mettre à jour l\'élément. Réessayez.';
      final confirmed = Map<String, PartState>.from(state.confirmedStates)
        ..remove(partId);
      final confirmedSources = Map<String, PartState>.from(
        state.confirmedSourceStates,
      )..remove(partId);
      final failed =
          Map<String, PendingPartUpdate>.from(state.lastFailedRequests)
            ..[partId] = PendingPartUpdate(
              previousState: previousState,
              selectedState: newState,
              previousComments: normalizedPreviousComments,
              selectedComments: normalizedComments,
              requestVersion: requestVersion,
              sourceState: sourceState,
            );

      state = state.copyWith(
        pendingUpdates: pending,
        errors: errors,
        confirmedStates: confirmed,
        confirmedSourceStates: confirmedSources,
        lastFailedRequests: failed,
      );
      return PartUpdateResult.failure;
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
      previousComments: pending.previousComments,
      newComments: pending.selectedComments,
    );
  }

  PendingPartUpdate? failedRequestFor(String partId) =>
      state.lastFailedRequests[partId];
}

String? _normalizeComments(String? comments) {
  final normalized = comments?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

enum PartUpdateResult { success, failure, stale, noChange }

class PartUpdateState {
  final Map<String, PendingPartUpdate> pendingUpdates;
  final Map<String, int> requestVersions;
  final Map<String, String> errors;
  final Map<String, PartState> confirmedStates;
  final Map<String, PartState> confirmedSourceStates;
  final Map<String, PendingPartUpdate> lastFailedRequests;

  const PartUpdateState({
    this.pendingUpdates = const {},
    this.requestVersions = const {},
    this.errors = const {},
    this.confirmedStates = const {},
    this.confirmedSourceStates = const {},
    this.lastFailedRequests = const {},
  });

  PartUpdateState copyWith({
    Map<String, PendingPartUpdate>? pendingUpdates,
    Map<String, int>? requestVersions,
    Map<String, String>? errors,
    Map<String, PartState>? confirmedStates,
    Map<String, PartState>? confirmedSourceStates,
    Map<String, PendingPartUpdate>? lastFailedRequests,
  }) {
    return PartUpdateState(
      pendingUpdates: pendingUpdates ?? this.pendingUpdates,
      requestVersions: requestVersions ?? this.requestVersions,
      errors: errors ?? this.errors,
      confirmedStates: confirmedStates ?? this.confirmedStates,
      confirmedSourceStates:
          confirmedSourceStates ?? this.confirmedSourceStates,
      lastFailedRequests: lastFailedRequests ?? this.lastFailedRequests,
    );
  }

  PartState resolveDisplayedState(Part part) {
    final pending = pendingUpdates[part.id];
    if (pending != null) {
      return pending.selectedState;
    }

    final confirmed = confirmedStates[part.id];
    if (confirmed == null || part.state == confirmed) {
      return part.state;
    }

    if (part.state != confirmedSourceStates[part.id]) {
      return part.state;
    }

    return confirmed;
  }

  bool isSaving(String partId) => pendingUpdates.containsKey(partId);

  String? errorFor(String partId) => errors[partId];
}

class PendingPartUpdate {
  final PartState previousState;
  final PartState selectedState;
  final String? previousComments;
  final String? selectedComments;
  final int requestVersion;
  final PartState sourceState;

  const PendingPartUpdate({
    required this.previousState,
    required this.selectedState,
    required this.previousComments,
    required this.selectedComments,
    required this.requestVersion,
    required this.sourceState,
  });
}
