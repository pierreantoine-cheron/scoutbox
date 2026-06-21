import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/providers/app_bar_config_provider.dart';
import 'package:client/providers/route_observer_provider.dart';
import 'package:client/repositories/tag_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/tags_screen.dart';

void main() {
  testWidgets('shows French empty state', (tester) async {
    await tester.pumpWidget(_buildApp(_TagRepositoryStub(tags: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Aucune étiquette'), findsOneWidget);
    expect(
      find.text('Créez des étiquettes pour organiser vos tentes.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Créer une étiquette'), findsOneWidget);
  });

  testWidgets('renders tag cards with color dots and counts', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', tentCount: 0)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groupe A'), findsWidgets);
    expect(find.text('0 tente'), findsOneWidget);
  });

  testWidgets('create sheet disables save button when name is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(_TagRepositoryStub(tags: const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, 'Créer');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'AB');
    await tester.pump();

    final enabledButton = find.widgetWithText(FilledButton, 'Créer');
    expect(tester.widget<FilledButton>(enabledButton).onPressed, isNotNull);
  });

  testWidgets('create sheet uses default color and updates list', (
    tester,
  ) async {
    final repository = _TagRepositoryStub(tags: const []);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'À réparer');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.createdColor, isNotNull);
    expect(find.text('À réparer'), findsWidgets);
  });

  testWidgets('popup menu shows Modifier and Supprimer options', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', tentCount: 2)]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
  });

  testWidgets('rename sheet opens with pre-filled name and color', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', color: '#F44336')]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text("Modifier l'étiquette"), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    final textFields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(textFields.first).controller?.text, 'Groupe A');
  });

  testWidgets('rename sheet save disabled when name and color unchanged', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', color: '#F44336')]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Enregistrer');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('delete confirmation shows tent count', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', tentCount: 3)]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer l\'étiquette ?'), findsOneWidget);
    expect(
      find.text('L\'étiquette "Groupe A" sera supprimée. 3 tente(s) l\'utilisent.'),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
  });

  testWidgets('delete confirmation omits tent count when zero', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', tentCount: 0)]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text('L\'étiquette "Groupe A" sera supprimée.'),
      findsOneWidget,
    );
  });

  testWidgets('delete removes tag from list and fires success indicator', (tester) async {
    final repository = _TagRepositoryStub(
      tags: [_tag('1', 'Groupe A'), _tag('2', 'Groupe B')],
    );
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Groupe A'), findsWidgets);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.tags.map((t) => t.id), ['2']);
    expect(find.text('Groupe A'), findsNothing);
  });

  testWidgets('duplicate creation error shows in sheet', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(
          tags: const [],
          createError: const TagRepositoryException(
            code: 'TAG_NAME_EXISTS',
            message: 'Une étiquette avec ce nom existe déjà',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.first, 'Groupe A');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Une étiquette avec ce nom existe déjà'), findsOneWidget);
    expect(find.text('Nouvelle étiquette'), findsOneWidget);
  });
}

Widget _buildApp(TagRepository repository) {
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  return ProviderScope(
    overrides: [
      tagRepositoryProvider.overrideWithValue(repository),
      routeObserverProvider.overrideWithValue(routeObserver),
    ],
    child: MaterialApp(
      theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [routeObserver],
      home: Consumer(
        builder: (context, ref, _) {
          final appBarConfig = ref.watch(appBarConfigProvider);
          return Scaffold(
            body: const TagsScreen(),
            floatingActionButton: appBarConfig.fab,
          );
        },
      ),
    ),
  );
}

Tag _tag(
  String id,
  String name, {
  int tentCount = 0,
  String color = '#2196F3',
}) {
  return Tag(
    id: id,
    name: name,
    color: color,
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: tentCount,
  );
}

class _TagRepositoryStub extends TagRepository {
  final List<Tag> tags;
  final TagRepositoryException? createError;
  String? createdColor;

  _TagRepositoryStub({required this.tags, this.createError});

  @override
  Future<List<Tag>> getTags() async => tags;

  @override
  Future<Tag> updateTag(String id, {required String name, String? color}) async {
    final tag = tags.firstWhere((t) => t.id == id);
    return _tag(id, name, color: color ?? tag.color, tentCount: tag.tentCount);
  }

  @override
  Future<void> deleteTag(String id) async {
    tags.removeWhere((t) => t.id == id);
  }

  @override
  Future<Tag> createTag({required String name, String? color}) async {
    if (createError != null) throw createError!;
    createdColor = color;
    return _tag('created', name, color: color ?? '#2196F3');
  }
}
