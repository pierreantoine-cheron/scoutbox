import 'package:client/models/part.dart';
import 'package:client/models/part_kind.dart';
import 'package:client/models/tent.dart';
import 'package:client/providers/part_management_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartManagementNotifier', () {
    test('clears add errors before retrying successfully', () async {
      final repository = _PartManagementRepository()..failNextAdd = true;
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        partManagementProvider('tent-1').notifier,
      );

      final failed = await notifier.addParts(const ['kind-1']);
      expect(failed, isFalse);
      expect(
        container.read(partManagementProvider('tent-1')).addError,
        'Une erreur est survenue. Veuillez réessayer.',
      );

      final succeeded = await notifier.addParts(const ['kind-1']);
      expect(succeeded, isTrue);
      expect(container.read(partManagementProvider('tent-1')).addError, isNull);
    });

    test('clears remove errors before retrying successfully', () async {
      final repository = _PartManagementRepository()..failNextRemove = true;
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        partManagementProvider('tent-1').notifier,
      );

      final failed = await notifier.removePart('part-1');
      expect(failed, isFalse);
      expect(
        container.read(partManagementProvider('tent-1')).removeError,
        'Une erreur est survenue. Veuillez réessayer.',
      );

      final succeeded = await notifier.removePart('part-1');
      expect(succeeded, isTrue);
      expect(
        container.read(partManagementProvider('tent-1')).removeError,
        isNull,
      );
    });
  });
}

class _PartManagementRepository extends TentRepository {
  bool failNextAdd = false;
  bool failNextRemove = false;

  @override
  Future<List<PartKind>> getPartKinds() async => const [
    PartKind(id: 'kind-1', name: 'Toile', displayOrder: 1, tentCount: 0),
  ];

  @override
  Future<List<Part>> addPartsToTent({
    required String tentId,
    required List<String> partKindIds,
  }) async {
    if (failNextAdd) {
      failNextAdd = false;
      throw const TentRepositoryException(message: 'Ajout impossible.');
    }

    return const [
      Part(
        id: 'part-1',
        partKindId: 'kind-1',
        partKindName: 'Toile',
        displayOrder: 1,
        state: PartState.good,
        comments: null,
      ),
    ];
  }

  @override
  Future<void> removePart({required String partId}) async {
    if (failNextRemove) {
      failNextRemove = false;
      throw const TentRepositoryException(message: 'Suppression impossible.');
    }
  }

  @override
  Future<Tent> getTent(String id) async => Tent(
    id: id,
    name: 'Tente',
    size: 4,
    tentModelId: 'shape-1',
    overallState: TentOverallState.good,
    comments: null,
    parts: const [],
  );
}
