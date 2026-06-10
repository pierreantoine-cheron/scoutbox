import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/providers/app_bar_config_provider.dart';
import 'package:client/providers/route_observer_provider.dart';
import 'package:client/repositories/tag_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/tags_screen.dart';

void main() {
  testWidgets('shows French empty state', (tester) async {
    await tester.pumpWidget(_buildApp(_TagRepositoryStub(tags: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Aucune étiquette disponible'), findsOneWidget);
    expect(find.text('Créez votre première étiquette.'), findsOneWidget);
  });

  testWidgets('renders tag list with color labels and counts', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(tags: [_tag('1', 'Groupe A', tentCount: 0)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groupe A'), findsWidgets);
    expect(find.text('0 tente'), findsOneWidget);
  });

  testWidgets('create dialog validates name and exposes accessible colors', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(_TagRepositoryStub(tags: const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pump();

    expect(find.text('Le nom de l\'étiquette est requis'), findsOneWidget);
    expect(find.text('Rouge'), findsOneWidget);
    expect(find.text('Bleu'), findsOneWidget);
  });

  testWidgets('create dialog uses default blue color and updates list', (
    tester,
  ) async {
    final repository = _TagRepositoryStub(tags: const []);
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'À réparer');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(repository.createdColor, equals('#1A70E5'));
    expect(find.text('À réparer'), findsWidgets);
  });

  testWidgets('duplicate creation error keeps dialog open', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _TagRepositoryStub(
          tags: const [],
          createError: const TagRepositoryException(
            code: 'TAG_NAME_EXISTS',
            message: 'Une étiquette avec ce nom existe déjà',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Groupe A');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(find.text('Une étiquette avec ce nom existe déjà'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

Widget _buildApp(TagRepository repository) {
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  return ProviderScope(
    overrides: [
      tagRepositoryProvider.overrideWithValue(repository),
      routeObserverProvider.overrideWithValue(routeObserver),
    ],
    child: MaterialApp(
      theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [routeObserver],
      home: Consumer(
        builder: (context, ref, _) {
          final appBarConfig = ref.watch(appBarConfigProvider);
          return Scaffold(
            body: const TagsScreen(),
            floatingActionButton: appBarConfig.fab,
          );
        },
      ),
    ),
  );
}

Tag _tag(
  String id,
  String name, {
  int tentCount = 0,
  String color = '#2196F3',
}) {
  return Tag(
    id: id,
    name: name,
    color: color,
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: tentCount,
  );
}

class _TagRepositoryStub extends TagRepository {
  final List<Tag> tags;
  final TagRepositoryException? createError;
  String? createdColor;

  _TagRepositoryStub({required this.tags, this.createError});

  @override
  Future<List<Tag>> getTags() async => tags;

  @override
  Future<Tag> createTag({required String name, String? color}) async {
    if (createError != null) throw createError!;
    createdColor = color;
    return _tag('created', name, color: color ?? '#2196F3');
  }
}
