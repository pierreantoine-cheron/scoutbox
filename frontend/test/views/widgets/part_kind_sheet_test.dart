import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/repositories/part_kind_repository.dart';
import 'package:client/utils/constants.dart';
import 'package:client/views/widgets/part_kind_sheet.dart';

void main() {
  testWidgets('create mode shows title and save button', (tester) async {
    await tester.pumpWidget(_buildSheet(initialName: null));

    expect(find.text('Nouvel élément'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Créer'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Annuler'), findsOneWidget);
  });

  testWidgets('rename mode shows title and pre-filled name', (tester) async {
    await tester.pumpWidget(_buildSheet(initialName: 'Arceaux'));

    expect(find.text("Modifier l'élément"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Enregistrer'), findsOneWidget);
    expect(find.text('Arceaux'), findsOneWidget);
  });

  testWidgets('save is disabled when name is empty', (tester) async {
    await tester.pumpWidget(_buildSheet(initialName: null));

    final createButton = find.widgetWithText(FilledButton, 'Créer');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    final textField = find.byType(TextFormField);
    await tester.enterText(textField, 'Arceaux');
    await tester.pump();

    final enabledButton = find.widgetWithText(FilledButton, 'Créer');
    expect(tester.widget<FilledButton>(enabledButton).onPressed, isNotNull);
  });

  testWidgets('save is disabled in rename mode when name unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSheet(initialName: 'Arceaux'));

    final saveButton = find.widgetWithText(FilledButton, 'Enregistrer');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    final textField = find.byType(TextFormField);
    await tester.enterText(textField, 'Modified');
    await tester.pump();

    final enabledButton = find.widgetWithText(FilledButton, 'Enregistrer');
    expect(tester.widget<FilledButton>(enabledButton).onPressed, isNotNull);
  });

  testWidgets('duplicate error shows in sheet', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        initialName: null,
        onSave: (_) => throw const PartKindRepositoryException(
          code: 'PART_KIND_NAME_EXISTS',
          message: 'Un élément avec ce nom existe déjà',
        ),
      ),
    );

    final textField = find.byType(TextFormField);
    await tester.enterText(textField, 'Duplicate');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Un élément avec ce nom existe déjà'), findsOneWidget);
  });

  testWidgets('name field is limited to 60 characters', (tester) async {
    await tester.pumpWidget(_buildSheet(initialName: null));

    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(textField.maxLength, equals(ValidationConstants.partKindNameMaxLength));
  });

  testWidgets('rename mode generic failure shows rename error', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        initialName: 'Arceaux',
        onSave: (_) => throw Exception('boom'),
      ),
    );

    final textField = find.byType(TextFormField);
    await tester.enterText(textField, 'Arceaux modifié');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Impossible de renommer l\'élément. Réessayez.'), findsOneWidget);
  });
}

Widget _buildSheet({
  String? initialName,
  Future<void> Function(String name)? onSave,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProviderScope(
        child: PartKindSheet(
          initialName: initialName,
          onSave: onSave ?? (_) async {},
        ),
      ),
    ),
  );
}
