import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/part_kind.dart';
import 'package:client/providers/part_kinds_provider.dart';
import 'package:client/repositories/part_kind_repository.dart';

void main() {
  group('PartKindsNotifier', () {
    test('loads part kinds on initialization', () async {
      final repository = _PartKindRepositoryStub(partKinds: [
        _partKind('1', 'Arceaux'),
      ]);
      final container = ProviderContainer(
        overrides: [partKindRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final partKinds = await container.read(partKindsProvider.future);

      expect(partKinds, hasLength(1));
      expect(partKinds.first.name, equals('Arceaux'));
    });

    test('createPartKind inserts created part kind', () async {
      final repository = _PartKindRepositoryStub(partKinds: [
        _partKind('2', 'Sardines'),
      ]);
      final container = ProviderContainer(
        overrides: [partKindRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(partKindsProvider.future);

      await container
          .read(partKindsProvider.notifier)
          .createPartKind(name: 'Arceaux');

      final partKinds = container.read(partKindsProvider).requireValue;
      expect(partKinds.map((pk) => pk.name), equals(['Sardines', 'Arceaux']));
    });

    test('renamePartKind updates name in list', () async {
      final repository = _PartKindRepositoryStub(partKinds: [
        _partKind('1', 'Old Name'),
      ]);
      final container = ProviderContainer(
        overrides: [partKindRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(partKindsProvider.future);

      await container
          .read(partKindsProvider.notifier)
          .renamePartKind('1', name: 'New Name');

      final partKinds = container.read(partKindsProvider).requireValue;
      expect(partKinds.first.name, equals('New Name'));
    });

    test('deletePartKind removes from list', () async {
      final repository = _PartKindRepositoryStub(partKinds: [
        _partKind('1', 'Arceaux'),
        _partKind('2', 'Sardines'),
      ]);
      final container = ProviderContainer(
        overrides: [partKindRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(partKindsProvider.future);

      await container.read(partKindsProvider.notifier).deletePartKind('1');

      final partKinds = container.read(partKindsProvider).requireValue;
      expect(partKinds, hasLength(1));
      expect(partKinds.first.id, equals('2'));
    });

    test('keeps existing data and exposes refresh failure', () async {
      final repository = _RefreshFailurePartKindRepository();
      final container = ProviderContainer(
        overrides: [partKindRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(partKindsProvider.future);

      await container.read(partKindsProvider.notifier).refresh();

      expect(
        container.read(partKindsProvider).requireValue.first.name,
        equals('Initial'),
      );
      expect(
        container.read(partKindsRefreshIssueProvider),
        isA<PartKindRepositoryException>(),
      );
    });
  });
}

PartKind _partKind(String id, String name, {int tentCount = 0}) {
  return PartKind(
    id: id,
    name: name,
    displayOrder: 0,
    tentCount: tentCount,
  );
}

class _PartKindRepositoryStub extends PartKindRepository {
  final List<PartKind> partKinds;
  int createdCount = 0;

  _PartKindRepositoryStub({required this.partKinds});

  @override
  Future<List<PartKind>> getPartKinds() async => partKinds;

  @override
  Future<PartKind> createPartKind({required String name}) async {
    createdCount++;
    return _partKind('created-$createdCount', name);
  }

  @override
  Future<PartKind> renamePartKind(String id, {required String name}) async {
    return _partKind(id, name);
  }

  @override
  Future<void> deletePartKind(String id) async {}
}

class _RefreshFailurePartKindRepository extends PartKindRepository {
  var callCount = 0;

  @override
  Future<List<PartKind>> getPartKinds() async {
    callCount++;
    if (callCount == 1) return [_partKind('1', 'Initial')];
    throw const PartKindRepositoryException(message: 'Échec refresh');
  }
}
