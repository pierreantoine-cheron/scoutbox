import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client/models/tent.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/providers/tent_creation_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/constants.dart';

void main() {
  group('TentCreationNotifier', () {
    test('submit success creates tent with expected payload', () async {
      final repository = _CapturingTentRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tentCreationProvider.notifier);
      notifier.selectModel(
        const TentModel(
          id: 'shape-1',
          name: 'Canadienne',
          displayOrder: 1,
          isActive: true,
        ),
      );
      notifier.updateName('  Tente Alpha  ');
      notifier.updateSize('6');
      notifier.updateOverallState(TentOverallState.needsRepair);
      notifier.updateComments('  A verifier  ');

      final created = await notifier.submit();

      expect(created, isNotNull);
      expect(repository.createTentCallCount, equals(1));
      expect(repository.lastName, equals('Tente Alpha'));
      expect(repository.lastSize, equals(6));
      expect(repository.lastTentModelId, equals('shape-1'));
      expect(repository.lastOverallState, equals(TentOverallState.needsRepair));
      expect(repository.lastComments, equals('A verifier'));
      expect(container.read(tentCreationProvider).submitError, isNull);
    });

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

        notifier.selectModel(
          const TentModel(
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
        expect(state.submitError, equals('Une tente avec ce nom existe déjà'));
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
        equals('La taille doit être un nombre positif'),
      );
      expect(
        notifier.validateSize('12.5'),
        equals('La taille doit être un nombre positif'),
      );
      expect(
        notifier.validateSize('-2'),
        equals('La taille doit être un nombre positif'),
      );
      expect(notifier.validateSize('10'), isNull);
    });

    test('maps tent creation error codes to french messages', () async {
      Future<void> expectCodeMessage(
        String? code,
        String expectedMessage,
      ) async {
        final container = ProviderContainer(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _FailingTentRepository(errorCode: code),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(tentCreationProvider.notifier);
        notifier.selectModel(
          const TentModel(
            id: 'shape-1',
            name: 'Canadienne',
            displayOrder: 1,
            isActive: true,
          ),
        );
        notifier.updateName('Tente A');
        notifier.updateSize('6');

        await notifier.submit();
        expect(
          container.read(tentCreationProvider).submitError,
          expectedMessage,
        );
      }

      await expectCodeMessage(
        ErrorCodes.tentNameRequired,
        'Le nom de la tente est requis',
      );
      await expectCodeMessage(
        ErrorCodes.invalidTentSize,
        'La taille doit être comprise entre 1 et 100',
      );
      await expectCodeMessage(
        ErrorCodes.invalidTentModel,
        'Le modèle de tente sélectionné est invalide',
      );
      await expectCodeMessage(
        ErrorCodes.invalidTentState,
        "L'état de la tente est invalide",
      );
    });

    test('submit maps unknown repository failure to generic message', () async {
      final container = ProviderContainer(
        overrides: [
          tentRepositoryProvider.overrideWithValue(
            _UnexpectedFailingTentRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tentCreationProvider.notifier);
      notifier.selectModel(
        const TentModel(
          id: 'shape-1',
          name: 'Canadienne',
          displayOrder: 1,
          isActive: true,
        ),
      );
      notifier.updateName('Tente B');
      notifier.updateSize('7');

      final created = await notifier.submit();

      expect(created, isNull);
      expect(
        container.read(tentCreationProvider).submitError,
        equals('Erreur serveur. Réessayez.'),
      );
    });
  });
}

class _CapturingTentRepository extends TentRepository {
  int createTentCallCount = 0;
  String? lastName;
  int? lastSize;
  String? lastTentModelId;
  TentOverallState? lastOverallState;
  String? lastComments;

  @override
  Future<List<TentModel>> getTentModels() async {
    return const [];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) async {
    createTentCallCount++;
    lastName = name;
    lastSize = size;
    lastTentModelId = tentModelId;
    lastOverallState = overallState;
    lastComments = comments;

    return Tent(
      id: 'tent-1',
      name: name,
      size: size,
      tentModelId: tentModelId,
      overallState: overallState,
      comments: comments,
    );
  }
}

class _UnexpectedFailingTentRepository extends TentRepository {
  @override
  Future<List<TentModel>> getTentModels() async {
    return const [];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) {
    throw Exception('network timeout');
  }
}

class _FailingTentRepository extends TentRepository {
  final String? errorCode;

  _FailingTentRepository({this.errorCode = ErrorCodes.tentNameExists});

  @override
  Future<List<TentModel>> getTentModels() async {
    return const [];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) {
    throw TentRepositoryException(
      code: errorCode,
      message: 'Tent name already exists',
    );
  }
}
