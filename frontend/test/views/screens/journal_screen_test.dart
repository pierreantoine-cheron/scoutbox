import 'package:client/models/activity_item.dart';
import 'package:client/providers/route_observer_provider.dart';
import 'package:client/repositories/activity_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fake_activity_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('requests the default filter window on entry', (tester) async {
    final repository = FakeActivityRepository();
    String? seenCategory;
    String? seenWindow;
    int? seenLimit;
    repository.handler = (category, window, cursor, limit) async {
      seenCategory = category;
      seenWindow = window;
      seenLimit = limit;
      return const ActivityPage(items: []);
    };

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(seenCategory, 'all');
    expect(seenWindow, '30');
    expect(seenLimit, 50);
  });

  testWidgets('groups rows under local day headings and shows author and time', (
    tester,
  ) async {
    final repository = FakeActivityRepository();
    final now = DateTime.now();
    repository.handler = (category, window, cursor, limit) async {
      return ActivityPage(
        items: [
          _item(
            id: 'today',
            occurredAt: DateTime(now.year, now.month, now.day, 9, 30),
            tentName: 'Tente Atlas',
          ),
          _item(
            id: 'yesterday',
            occurredAt: DateTime(now.year, now.month, now.day, 21).subtract(const Duration(days: 1)),
            tentName: 'Tente Bouleau',
          ),
        ],
      );
    };

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.textContaining('09:30 • Jean Dupont'), findsOneWidget);
    expect(find.textContaining('21:00 • Jean Dupont'), findsOneWidget);
    expect(find.textContaining('Tente Atlas — Tente créée'), findsOneWidget);
  });

  testWidgets('shows the no activity empty state', (tester) async {
    final repository = FakeActivityRepository();
    repository.handler = (category, window, cursor, limit) async {
      return const ActivityPage(items: []);
    };

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Aucune activité'), findsOneWidget);
    expect(find.text('Aucun changement récent à afficher.'), findsOneWidget);
  });

  testWidgets('distinguishes a filtered empty result from no activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.minimal(),
        home: const Scaffold(body: JournalEmptyState(isFiltered: true)),
      ),
    );

    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Aucune activité'), findsNothing);
  });

  testWidgets('shows an error state and retries', (tester) async {
    final repository = FakeActivityRepository();
    var shouldFail = true;
    repository.handler = (category, window, cursor, limit) async {
      if (shouldFail) {
        throw const ActivityRepositoryException(message: 'Journal indisponible');
      }
      return ActivityPage(items: [_item(id: 'retry', tentName: 'Tente Atlas')]);
    };

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Journal indisponible'), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tente Atlas — Tente créée'), findsOneWidget);
  });

  testWidgets('pull-to-refresh refetches the journal', (tester) async {
    final repository = FakeActivityRepository();
    var calls = 0;
    repository.handler = (category, window, cursor, limit) async {
      calls++;
      return ActivityPage(
        items: [
          _item(
            id: 'item-$calls',
            tentName: calls == 1 ? 'Tente Atlas' : 'Tente Bouleau',
          ),
        ],
      );
    };

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.textContaining('Tente Bouleau'), findsOneWidget);
  });

  testWidgets('tapping a row opens its tent', (tester) async {
    final repository = FakeActivityRepository();
    repository.handler = (category, window, cursor, limit) async {
      return ActivityPage(items: [_item(id: 'tap', tentName: 'Tente Atlas')]);
    };
    String? openedTentId;

    await tester.pumpWidget(
      _buildApp(
        repository,
        onOpenTentDetail: (tentId) => openedTentId = tentId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Tente Atlas — Tente créée'));
    await tester.pumpAndSettle();

    expect(openedTentId, 'tent-1');
  });

  testWidgets('catalogue rows without a tent are not tappable', (tester) async {
    final repository = FakeActivityRepository();
    repository.handler = (category, window, cursor, limit) async {
      return ActivityPage(
        items: [
          _item(
            id: 'tag',
            action: 'tag_created',
            tentId: null,
            tentName: null,
            subjectName: 'Groupe A',
          ),
        ],
      );
    };
    String? openedTentId;

    await tester.pumpWidget(
      _buildApp(
        repository,
        onOpenTentDetail: (tentId) => openedTentId = tentId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Groupe A — Étiquette créée'));
    await tester.pumpAndSettle();

    expect(openedTentId, isNull);
  });
}

Widget _buildApp(
  ActivityRepository repository, {
  ValueChanged<String>? onOpenTentDetail,
}) {
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  return ProviderScope(
    overrides: [
      activityRepositoryProvider.overrideWithValue(repository),
      routeObserverProvider.overrideWithValue(routeObserver),
    ],
    child: MaterialApp(
      theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
      navigatorObservers: [routeObserver],
      home: Scaffold(
        body: JournalScreen(
          onOpenTentDetail: onOpenTentDetail ?? (_) {},
        ),
      ),
    ),
  );
}

ActivityItem _item({
  required String id,
  String action = 'tent_created',
  DateTime? occurredAt,
  String? tentId = 'tent-1',
  String? tentName = 'Tente Atlas',
  String? subjectName,
}) {
  return ActivityItem(
    id: id,
    action: action,
    category: 'tents',
    occurredAt: occurredAt ?? DateTime.now(),
    actorUserId: 'user-1',
    actorDisplayName: 'Jean Dupont',
    tentId: tentId,
    tentName: tentName,
    subjectName: subjectName,
    details: const [],
  );
}
