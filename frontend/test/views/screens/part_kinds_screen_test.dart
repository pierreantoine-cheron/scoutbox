import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/part_kind.dart';
import 'package:client/providers/app_bar_config_provider.dart';
import 'package:client/providers/route_observer_provider.dart';
import 'package:client/repositories/part_kind_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/part_kinds_screen.dart';

void main() {
  testWidgets('shows French empty state', (tester) async {
    await tester.pumpWidget(
      _buildApp(_PartKindRepositoryStub(partKinds: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun modèle de pièce'), findsOneWidget);
    expect(
      find.text('Créez des modèles de pièce pour composer vos modèles de tente.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Créer un modèle de pièce'), findsOneWidget);
  });

  testWidgets('renders part kind cards with names and tent counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        _PartKindRepositoryStub(partKinds: [
          _partKind('1', 'Arceaux', tentCount: 3),
          _partKind('2', 'Sardines', tentCount: 1),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arceaux'), findsWidgets);
    expect(find.text('Sardines'), findsWidgets);
    expect(find.text('3 tentes'), findsOneWidget);
    expect(find.text('1 tente'), findsOneWidget);
    expect(find.text('2 modèles de pièce'), findsOneWidget);
  });

  testWidgets('shows the plural count badge for several part kinds', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      _buildApp(
        _PartKindRepositoryStub(partKinds: [
          _partKind('1', 'Arceaux'),
          _partKind('2', 'Sardines'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modèles de pièce'), findsOneWidget);
    expect(find.text('2 modèles de pièce'), findsOneWidget);
  });

  testWidgets('shows the singular count badge for one part kind', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      _buildApp(
        _PartKindRepositoryStub(partKinds: [_partKind('1', 'Arceaux')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 modèle de pièce'), findsOneWidget);
  });

  testWidgets('create button opens sheet', (tester) async {
    final repository = _PartKindRepositoryStub(partKinds: const []);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau modèle de pièce'), findsOneWidget);
  });

  testWidgets('delete confirmation names the modèle de pièce', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _PartKindRepositoryStub(partKinds: [_partKind('1', 'Arceaux')]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le modèle de pièce ?'), findsOneWidget);
    expect(
      find.text('Le modèle de pièce "Arceaux" sera supprimé.'),
      findsOneWidget,
    );
  });

  testWidgets('creating part kind updates list', (tester) async {
    final repository = _PartKindRepositoryStub(partKinds: const []);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final textField = find.byType(TextFormField);
    await tester.enterText(textField, 'Arceaux');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Arceaux'), findsWidgets);
  });

  testWidgets('popup menu shows edit and delete options', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _PartKindRepositoryStub(partKinds: [
          _partKind('1', 'Arceaux'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
  });
}

Widget _buildApp(PartKindRepository repository) {
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  return ProviderScope(
    overrides: [
      partKindRepositoryProvider.overrideWithValue(repository),
      routeObserverProvider.overrideWithValue(routeObserver),
    ],
    child: MaterialApp(
      theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [routeObserver],
      home: Consumer(
        builder: (context, ref, _) {
          final appBarConfig = ref.watch(appBarConfigProvider);
          return Scaffold(
            appBar: AppBar(
              title: appBarConfig.title,
              actions: appBarConfig.actions,
            ),
            body: const PartKindsScreen(),
            floatingActionButton: appBarConfig.fab,
          );
        },
      ),
    ),
  );
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

PartKind _partKind(String id, String name, {int tentCount = 0}) {
  return PartKind(
    id: id,
    name: name,
    displayOrder: 0,
    tentCount: tentCount,
  );
}

class _PartKindRepositoryStub extends PartKindRepository {
  final List<PartKind> partKinds;
  int createdCount = 0;

  _PartKindRepositoryStub({required this.partKinds});

  @override
  Future<List<PartKind>> getPartKinds() async => partKinds;

  @override
  Future<PartKind> createPartKind({required String name}) async {
    createdCount++;
    return _partKind('created-$createdCount', name);
  }

  @override
  Future<PartKind> renamePartKind(String id, {required String name}) async {
    return _partKind(id, name);
  }

  @override
  Future<void> deletePartKind(String id) async {}
}
