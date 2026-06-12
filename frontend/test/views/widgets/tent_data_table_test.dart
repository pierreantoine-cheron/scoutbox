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
      expect(find.text('État'), findsAtLeast(1));
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

      expect(find.text('3 pl.'), findsOneWidget);
    });

    testWidgets('renders "1 pl." for size 1', (tester) async {
      await tester.pumpWidget(buildTable(tents: [_tent(size: 1)]));
      await tester.pumpAndSettle();

      expect(find.text('1 pl.'), findsOneWidget);
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

      expect(find.text('Aucune tente trouvée'), findsOneWidget);
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

    testWidgets('sorts rows when header is tapped', (
      tester,
    ) async {
      _setWideViewport(tester);
      await tester.pumpWidget(
        buildTable(
          tents: [
            _tent(name: 'Zèbre'),
            _tent(id: 't-2', name: 'Alpaga'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initial order: Zèbre first, Alpaga second
      final nameTextsBefore = _nameTextsInOrder(tester);
      expect(nameTextsBefore[0], 'Zèbre');
      expect(nameTextsBefore[1], 'Alpaga');

      // Tap "Nom" to sort ascending
      await tester.tap(find.text('Nom'));
      await tester.pumpAndSettle();

      // After sort: Alpaga first, Zèbre second
      final nameTextsAfter = _nameTextsInOrder(tester);
      expect(nameTextsAfter[0], 'Alpaga');
      expect(nameTextsAfter[1], 'Zèbre');
    });
  });
}

void _setWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<String> _nameTextsInOrder(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .where((w) => w.style?.fontSize == 15)
      .map((w) => w.data ?? '')
      .toList();
}
