import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/tent.dart';
import 'package:frontend/models/tent_shape.dart';
import 'package:frontend/providers/tent_creation_provider.dart';
import 'package:frontend/repositories/tent_repository.dart';
import 'package:frontend/utils/constants.dart';

void main() {
  group('TentCreationNotifier', () {
    test(
      'submit maps backend duplicate-name error to french message',
      () async {
        final container = ProviderContainer(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(tentCreationProvider.notifier);

        notifier.selectShape(
          const TentShape(
            id: 'shape-1',
            name: 'Canadienne',
            displayOrder: 1,
            isActive: true,
          ),
        );
        notifier.updateName('Tente A');
        notifier.updateSize('6');

        final created = await notifier.submit();
        final state = container.read(tentCreationProvider);

        expect(created, isNull);
        expect(state.name, equals('Tente A'));
        expect(state.sizeInput, equals('6'));
        expect(state.submitError, equals('Une tente avec ce nom existe deja'));
      },
    );

    test('validateSize rejects non-positive and non-integer values', () {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tentCreationProvider.notifier);

      expect(
        notifier.validateSize('0'),
        equals('La taille doit etre un nombre positif'),
      );
      expect(
        notifier.validateSize('12.5'),
        equals('La taille doit etre un nombre positif'),
      );
      expect(
        notifier.validateSize('-2'),
        equals('La taille doit etre un nombre positif'),
      );
      expect(notifier.validateSize('10'), isNull);
    });
  });
}

class _FailingTentRepository extends TentRepository {
  @override
  Future<List<TentShape>> getTentShapes() async {
    return const [];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required String overallState,
    String? comments,
  }) {
    throw const TentRepositoryException(
      code: ErrorCodes.tentNameExists,
      message: 'Tent name already exists',
    );
  }
}
