import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
import 'package:client/repositories/tag_repository.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/tag_assignment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TagAssignmentSheet', () {
    testWidgets('renders available tags with assigned group', (tester) async {
      await tester.pumpWidget(_buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Modifier les \u00e9tiquettes'), findsOneWidget);
      expect(find.text('Rechercher'), findsOneWidget);
      expect(find.text('Groupe A'), findsOneWidget);
      expect(find.text('Stock'), findsOneWidget);
    });

    testWidgets('toggle saves complete tag list optimistically', (
      tester,
    ) async {
      final tentRepository = _TentRepositoryStub();

      await tester.pumpWidget(_buildWidget(tentRepository: tentRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tentRepository.lastTagIds, containsAll(['tag-1', 'tag-2']));
    });

    testWidgets('toggle assigned tag off saves reduced tag list', (
      tester,
    ) async {
      final tentRepository = _TentRepositoryStub();

      await tester.pumpWidget(_buildWidget(tentRepository: tentRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Groupe A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tentRepository.lastTagIds, isNot(contains('tag-1')));
      expect(tentRepository.lastTagIds, isEmpty);
    });

    testWidgets('shows empty state when no tags exist', (tester) async {
      await tester.pumpWidget(_buildWidget(tags: const []));
      await tester.pumpAndSettle();

      expect(
        find.text("Aucune étiquette disponible. Créez d'abord des étiquettes."),
        findsOneWidget,
      );
      expect(find.text('Créer une étiquette'), findsOneWidget);
    });

    testWidgets('close button dismisses the sheet route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagRepositoryProvider.overrideWithValue(
              _TagRepositoryStub([_tag('tag-1', 'Groupe A')]),
            ),
            tentRepositoryProvider.overrideWithValue(_TentRepositoryStub()),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const TagAssignmentSheet(
                        tentId: 'tent-1',
                        assignedTagIds: {'tag-1'},
                      ),
                    ),
                    child: const Text('Ouvrir'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier les \u00e9tiquettes'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier les \u00e9tiquettes'), findsNothing);
    });

    testWidgets('reverts selection and shows inline error on failure', (
      tester,
    ) async {
      final tentRepository = _TentRepositoryStub(shouldFail: true);

      await tester.pumpWidget(_buildWidget(tentRepository: tentRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Une erreur est survenue. Veuillez r\u00e9essayer.'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildWidget({List<Tag>? tags, _TentRepositoryStub? tentRepository}) {
  return ProviderScope(
    overrides: [
      tagRepositoryProvider.overrideWithValue(
        _TagRepositoryStub(
          tags ?? [_tag('tag-1', 'Groupe A'), _tag('tag-2', 'Stock')],
        ),
      ),
      tentRepositoryProvider.overrideWithValue(
        tentRepository ?? _TentRepositoryStub(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
      home: const Scaffold(
        body: TagAssignmentSheet(tentId: 'tent-1', assignedTagIds: {'tag-1'}),
      ),
    ),
  );
}

Tag _tag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    color: '#2196F3',
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: 0,
  );
}

Tent _tent(List<String> tagIds) {
  return Tent(
    id: 'tent-1',
    name: 'Tente Atlas',
    size: 6,
    tentModelId: 'model-1',
    tentModelName: 'Canadienne',
    overallState: TentOverallState.good,
    comments: null,
    tags: tagIds.map((id) => _tag(id, id == 'tag-1' ? 'Groupe A' : 'Stock')).toList(),
  );
}

class _TagRepositoryStub extends TagRepository {
  final List<Tag> tags;

  _TagRepositoryStub(this.tags);

  @override
  Future<List<Tag>> getTags() async => tags;
}

class _TentRepositoryStub extends TentRepository {
  final bool shouldFail;
  List<String> lastTagIds = const [];

  _TentRepositoryStub({this.shouldFail = false});

  @override
  Future<Tent> setTentTags({
    required String tentId,
    required List<String> tagIds,
  }) async {
    if (shouldFail) {
      throw const TentRepositoryException(
        message: 'Impossible de modifier les étiquettes.',
      );
    }

    lastTagIds = tagIds;
    return _tent(tagIds);
  }
}
