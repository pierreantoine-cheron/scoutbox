import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
import 'package:client/views/widgets/tent_data_table.dart';

Tent _tent({
  String id = 't-1',
  String name = 'Tente A',
  int size = 6,
  String? modelName = 'Canadienne',
  TentOverallState state = TentOverallState.good,
  DateTime? updatedAt,
  List<Tag> tags = const [],
}) {
  return Tent(
    id: id,
    name: name,
    size: size,
    tentModelId: 'shape-1',
    tentModelName: modelName,
    overallState: state,
    isArchived: false,
    comments: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    parts: const [],
    tags: tags,
  );
}

Tag _tag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    color: '#2196F3',
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: 1,
  );
}

void main() {
  group('TentDataTable', () {
    Widget buildTable({required List<Tent> tents, ValueChanged<Tent>? onTap}) {
      return MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: SizedBox(
            width: 1400,
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
      expect(find.text('Modèle'), findsAtLeast(1));
      expect(find.text('Étiquettes'), findsAtLeast(1));
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
      await tester.pumpWidget(buildTable(tents: [_tent(modelName: 'Cabanon')]));
      await tester.pumpAndSettle();

      expect(find.text('Cabanon'), findsOneWidget);
    });

    testWidgets('renders assigned tags in rows', (tester) async {
      await tester.pumpWidget(
        buildTable(
          tents: [
            _tent(tags: [_tag('tag-1', 'Patrouille')]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Patrouille'), findsOneWidget);
    });

    testWidgets('renders no-tag fallback in rows', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent()]));
      await tester.pumpAndSettle();

      expect(find.text('-'), findsAtLeast(1));
    });

    testWidgets('renders "-" for missing shape name', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(modelName: '')]));
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

    testWidgets('calls onOpenTent when row with tags is tapped', (
      tester,
    ) async {
      _setWideViewport(tester);
      Tent? opened;
      await tester.pumpWidget(
        buildTable(
          tents: [
            _tent(name: 'Tente T', tags: [_tag('tag-1', 'Patrouille')]),
          ],
          onTap: (t) => opened = t,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Patrouille'));
      expect(opened?.name, 'Tente T');
    });

    testWidgets('keeps sort indicator aligned after tag column insertion', (
      tester,
    ) async {
      _setWideViewport(tester);
      await tester.pumpWidget(
        buildTable(
          tents: [
            _tent(name: 'Tente A', updatedAt: DateTime(2026, 1, 1)),
            _tent(id: 't-2', name: 'Tente B', updatedAt: DateTime(2026, 1, 2)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Derniere mise a jour'));
      await tester.pumpAndSettle();

      final table = tester.widget<DataTable2>(find.byType(DataTable2));
      expect(table.sortColumnIndex, 5);
    });
  });
}

void _setWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
