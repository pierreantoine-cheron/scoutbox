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

    expect(find.text('Aucun élément'), findsOneWidget);
    expect(
      find.text('Créez des types d\'éléments pour composer vos modèles de tentes.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Créer un élément'), findsOneWidget);
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
  });

  testWidgets('create button opens sheet', (tester) async {
    final repository = _PartKindRepositoryStub(partKinds: const []);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Nouvel élément'), findsOneWidget);
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
            body: const PartKindsScreen(),
            floatingActionButton: appBarConfig.fab,
          );
        },
      ),
    ),
  );
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
