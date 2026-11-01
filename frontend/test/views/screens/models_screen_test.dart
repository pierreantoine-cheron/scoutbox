import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/providers/app_bar_config_provider.dart';
import 'package:client/providers/route_observer_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/models_screen.dart';

void main() {
  testWidgets('shows French empty state with modèle de tente copy', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(_buildApp(_TentRepositoryStub(models: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Modèles de tente'), findsOneWidget);
    expect(find.text('Aucun modèle de tente'), findsOneWidget);
    expect(
      find.text('Créez un modèle de tente avec ses modèles de pièce.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Créer un modèle de tente'), findsOneWidget);
  });

  testWidgets('shows the plural count badge for several modèles de tente', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      _buildApp(
        _TentRepositoryStub(
          models: [
            _model('1', 'Canadienne', displayOrder: 1),
            _model('2', 'Dôme', displayOrder: 2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modèles de tente'), findsOneWidget);
    expect(find.text('2 modèles de tente'), findsOneWidget);
  });

  testWidgets('shows the singular count badge for one modèle de tente', (
    tester,
  ) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      _buildApp(
        _TentRepositoryStub(
          models: [_model('1', 'Canadienne', displayOrder: 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 modèle de tente'), findsOneWidget);
  });

  testWidgets('renders model rows with tent and modèle de pièce counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        _TentRepositoryStub(
          models: [
            _model(
              '1',
              'Canadienne',
              displayOrder: 1,
              tentCount: 3,
              componentCount: 2,
            ),
            _model(
              '2',
              'Dôme',
              displayOrder: 2,
              tentCount: 1,
              componentCount: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canadienne'), findsOneWidget);
    expect(find.text('3 tentes'), findsOneWidget);
    expect(find.text('2 modèles de pièce'), findsOneWidget);
    expect(find.text('1 tente'), findsOneWidget);
    expect(find.text('1 modèle de pièce'), findsOneWidget);
  });

  testWidgets('delete confirmation names the modèle de tente', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TentRepositoryStub(
          models: [_model('1', 'Canadienne', displayOrder: 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer le modèle de tente ?'), findsOneWidget);
    expect(
      find.text('Le modèle de tente "Canadienne" sera supprimé.'),
      findsOneWidget,
    );
  });

  testWidgets('delete confirmation explains a modèle de tente in use', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        _TentRepositoryStub(
          models: [
            _model('1', 'Canadienne', displayOrder: 1, tentCount: 2),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Le modèle de tente "Canadienne" est utilisé par 2 tentes. '
        'Impossible de le supprimer.',
      ),
      findsOneWidget,
    );
  });
}

Widget _buildApp(TentRepository repository) {
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  return ProviderScope(
    overrides: [
      tentRepositoryProvider.overrideWithValue(repository),
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
            body: const ModelsScreen(),
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

TentModel _model(
  String id,
  String name, {
  required int displayOrder,
  int tentCount = 0,
  int componentCount = 0,
}) {
  return TentModel(
    id: id,
    name: name,
    displayOrder: displayOrder,
    isActive: true,
    tentCount: tentCount,
    componentCount: componentCount,
  );
}

class _TentRepositoryStub extends TentRepository {
  final List<TentModel> models;

  _TentRepositoryStub({required this.models});

  @override
  Future<List<TentModel>> getTentModels() async => models;

  @override
  Future<void> deleteTentModel(String id) async {}
}
