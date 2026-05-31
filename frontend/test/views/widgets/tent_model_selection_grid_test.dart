import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/views/widgets/tent_model_selection_grid.dart';

TentModel _model({required String id, required String name}) {
  return TentModel(id: id, name: name, displayOrder: 1, isActive: true);
}

void main() {
  group('TentModelSelectionGrid', () {
    final models = [
      _model(id: 'model-1', name: 'Canadienne'),
      _model(id: 'model-2', name: 'Cabanon'),
      _model(id: 'model-3', name: 'Tipi'),
      _model(id: 'model-4', name: 'Marabout'),
    ];

    Widget buildGrid({
      required List<TentModel> models,
      TentModel? selectedModel,
      ValueChanged<TentModel>? onSelect,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TentModelSelectionGrid(
            models: models,
            selectedModel: selectedModel,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders all model names', (tester) async {
      await tester.pumpWidget(buildGrid(models: models));

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Cabanon'), findsOneWidget);
      expect(find.text('Tipi'), findsOneWidget);
      expect(find.text('Marabout'), findsOneWidget);
    });

    testWidgets('renders check icon on selected model', (tester) async {
      await tester.pumpWidget(
        buildGrid(models: models, selectedModel: models[0]),
      );

      // The first model has the check icon
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('model-model-1')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );

      // Other models don't have check icon
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('model-model-2')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );
    });

    testWidgets('no check icon when nothing selected', (tester) async {
      await tester.pumpWidget(buildGrid(models: models, selectedModel: null));

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('calls onSelect when model is tapped', (tester) async {
      TentModel? selected;
      await tester.pumpWidget(
        buildGrid(models: models, onSelect: (s) => selected = s),
      );

      await tester.tap(find.text('Tipi'));
      expect(selected?.name, 'Tipi');
    });

    testWidgets('renders empty grid when models list is empty', (tester) async {
      await tester.pumpWidget(buildGrid(models: const []));

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
