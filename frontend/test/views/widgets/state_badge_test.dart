import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/models.dart';
import 'package:client/views/widgets/state_badge.dart';

void main() {
  group('StateBadge', () {
    testWidgets('renders label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StateBadge(
              label: 'Bon état',
              icon: Icons.check_circle_outline,
              background: Colors.green,
              foreground: Colors.white,
            ),
          ),
        ),
      );

      expect(find.text('Bon état'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders part Missing state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StateBadge(
              label: 'Manquant',
              icon: Icons.remove_circle_outline,
              background: Colors.grey,
              foreground: Colors.white,
            ),
          ),
        ),
      );

      expect(find.text('Manquant'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });
  });

  group('tentStateBadgeStyle', () {
    testWidgets('each tent state has distinct label and icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final ctx = tester.element(find.byType(Scaffold));
      final styles = TentOverallState.values
          .map((s) => tentStateBadgeStyle(ctx, s))
          .toList();

      final labels = styles.map((s) => s.label).toSet();
      final icons = styles.map((s) => s.icon).toSet();
      expect(labels.length, 3);
      expect(icons.length, 3);
    });

    testWidgets('labels match French localization', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final ctx = tester.element(find.byType(Scaffold));

      expect(tentStateBadgeStyle(ctx, TentOverallState.good).label, 'Bon état');
      expect(
        tentStateBadgeStyle(ctx, TentOverallState.needsRepair).label,
        'À réparer',
      );
      expect(
        tentStateBadgeStyle(ctx, TentOverallState.unusable).label,
        'Inutilisable',
      );
    });
  });

  group('partStateBadgeStyle', () {
    testWidgets('each part state has distinct label and icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final ctx = tester.element(find.byType(Scaffold));
      final styles = PartState.values
          .map((s) => partStateBadgeStyle(ctx, s))
          .toList();

      final labels = styles.map((s) => s.label).toSet();
      final icons = styles.map((s) => s.icon).toSet();
      expect(labels.length, 4);
      expect(icons.length, 4);
    });
  });
}
