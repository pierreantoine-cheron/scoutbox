import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/part_kind.dart';
import 'package:client/repositories/part_kind_repository.dart';
import 'package:client/views/widgets/tent_model_sheet.dart';

void main() {
  testWidgets('create mode names the modèle de tente and its modèles de pièce', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSheet(initialName: null));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau modèle de tente'), findsOneWidget);
    expect(find.text('Nom du modèle de tente'), findsOneWidget);
    expect(find.text('Modèles de pièce par défaut'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Créer'), findsOneWidget);
  });

  testWidgets('rename mode names the modèle de tente', (tester) async {
    await tester.pumpWidget(
      _buildSheet(initialName: 'Canadienne', initialComponentIds: const []),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier le modèle de tente'), findsOneWidget);
    expect(find.text('Canadienne'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Enregistrer'), findsOneWidget);
  });

  testWidgets('shows the modèle de pièce load error', (tester) async {
    await tester.pumpWidget(
      _buildSheet(initialName: null, partKindRepository: _FailingPartKindRepository()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de charger les modèles de pièce.'),
      findsOneWidget,
    );
  });

  testWidgets('create mode generic failure shows create error', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        initialName: null,
        onSave: (_, _) => throw Exception('boom'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Canadienne');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de créer le modèle de tente. Réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('rename mode generic failure shows update error', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        initialName: 'Canadienne',
        initialComponentIds: const [],
        onSave: (_, _) => throw Exception('boom'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Canadienne modifiée');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de modifier le modèle de tente. Réessayez.'),
      findsOneWidget,
    );
  });
}

Widget _buildSheet({
  String? initialName,
  List<String>? initialComponentIds,
  Future<void> Function(String name, List<String> componentIds)? onSave,
  PartKindRepository? partKindRepository,
}) {
  return ProviderScope(
    overrides: [
      partKindRepositoryProvider.overrideWithValue(
        partKindRepository ?? _PartKindRepositoryStub(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TentModelSheet(
          initialName: initialName,
          initialComponentIds: initialComponentIds,
          onSave: onSave ?? (_, _) async {},
        ),
      ),
    ),
  );
}

class _PartKindRepositoryStub extends PartKindRepository {
  @override
  Future<List<PartKind>> getPartKinds() async => const [];
}

class _FailingPartKindRepository extends PartKindRepository {
  @override
  Future<List<PartKind>> getPartKinds() async {
    throw Exception('boom');
  }
}
