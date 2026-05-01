import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent_shape.dart';
import 'package:client/views/widgets/tent_shape_selection_grid.dart';

TentShape _shape({required String id, required String name}) {
  return TentShape(
    id: id,
    name: name,
    displayOrder: 1,
    isActive: true,
  );
}

void main() {
  group('TentShapeSelectionGrid', () {
    final shapes = [
      _shape(id: 'shape-1', name: 'Canadienne'),
      _shape(id: 'shape-2', name: 'Cabanon'),
      _shape(id: 'shape-3', name: 'Tipi'),
      _shape(id: 'shape-4', name: 'Marabout'),
    ];

    Widget buildGrid({
      required List<TentShape> shapes,
      TentShape? selectedShape,
      ValueChanged<TentShape>? onSelect,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TentShapeSelectionGrid(
            shapes: shapes,
            selectedShape: selectedShape,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders all shape names', (tester) async {
      await tester.pumpWidget(buildGrid(shapes: shapes));

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Cabanon'), findsOneWidget);
      expect(find.text('Tipi'), findsOneWidget);
      expect(find.text('Marabout'), findsOneWidget);
    });

    testWidgets('renders check icon on selected shape', (tester) async {
      await tester.pumpWidget(
        buildGrid(shapes: shapes, selectedShape: shapes[0]),
      );

      // The first shape has the check icon
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shape-shape-1')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );

      // Other shapes don't have check icon
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shape-shape-2')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );
    });

    testWidgets('no check icon when nothing selected', (tester) async {
      await tester.pumpWidget(buildGrid(shapes: shapes, selectedShape: null));

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('calls onSelect when shape is tapped', (tester) async {
      TentShape? selected;
      await tester.pumpWidget(
        buildGrid(
          shapes: shapes,
          onSelect: (s) => selected = s,
        ),
      );

      await tester.tap(find.text('Tipi'));
      expect(selected?.name, 'Tipi');
    });

    testWidgets('renders empty grid when shapes list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid(shapes: const []));

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
