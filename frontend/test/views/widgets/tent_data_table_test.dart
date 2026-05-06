import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent.dart';
import 'package:client/views/widgets/tent_data_table.dart';

Tent _tent({
  String id = 't-1',
  String name = 'Tente A',
  int size = 6,
  String? shapeName = 'Canadienne',
  TentOverallState state = TentOverallState.good,
  DateTime? updatedAt,
}) {
  return Tent(
    id: id,
    name: name,
    size: size,
    tentShapeId: 'shape-1',
    tentShapeName: shapeName,
    overallState: state,
    isArchived: false,
    comments: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    parts: const [],
  );
}

void main() {
  group('TentDataTable', () {
    Widget buildTable({required List<Tent> tents, ValueChanged<Tent>? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: TentDataTable(tents: tents, onOpenTent: onTap ?? (_) {}),
          ),
        ),
      );
    }

    testWidgets('renders table with header columns', (tester) async {
      await tester.pumpWidget(
        buildTable(
          tents: [
            _tent(),
            _tent(id: 't-2', name: 'Tente B'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nom'), findsAtLeast(1));
      expect(find.text('Etat'), findsAtLeast(1));
      expect(find.text('Taille'), findsAtLeast(1));
      expect(find.text('Forme'), findsAtLeast(1));
    });

    testWidgets('renders tent names in rows', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(name: 'Tente Alpha')]));
      await tester.pumpAndSettle();

      expect(find.text('Tente Alpha'), findsOneWidget);
    });

    testWidgets('renders state french labels', (tester) async {
      await tester.pumpWidget(
        buildTable(
          tents: [_tent(name: 'T1', state: TentOverallState.needsRepair)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('À réparer'), findsOneWidget);
    });

    testWidgets('renders size as places', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(size: 3)]));
      await tester.pumpAndSettle();

      expect(find.text('3 places'), findsOneWidget);
    });

    testWidgets('renders "1 place" for size 1', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(size: 1)]));
      await tester.pumpAndSettle();

      expect(find.text('1 place'), findsOneWidget);
    });

    testWidgets('renders shape name', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(shapeName: 'Cabanon')]));
      await tester.pumpAndSettle();

      expect(find.text('Cabanon'), findsOneWidget);
    });

    testWidgets('renders "-" for missing shape name', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(shapeName: '')]));
      await tester.pumpAndSettle();

      expect(find.text('-'), findsAtLeast(1));
    });

    testWidgets('shows empty message when no tents', (tester) async {
      await tester.pumpWidget(buildTable(tents: const []));
      await tester.pumpAndSettle();

      expect(find.text('Aucune tente disponible'), findsOneWidget);
    });

    testWidgets('calls onOpenTent when row is tapped', (tester) async {
      Tent? opened;
      await tester.pumpWidget(
        buildTable(
          tents: [_tent(name: 'Tente T')],
          onTap: (t) => opened = t,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente T'));
      expect(opened?.name, 'Tente T');
    });
  });
}
