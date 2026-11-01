import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/count_badge.dart';

void main() {
  testWidgets('pluralizes a single-word label by adding s', (tester) async {
    await tester.pumpWidget(_badge(const CountBadge(count: 2, label: 'tente')));

    expect(find.text('2 tentes'), findsOneWidget);
  });

  testWidgets('keeps a single-word label singular for one', (tester) async {
    await tester.pumpWidget(_badge(const CountBadge(count: 1, label: 'tente')));

    expect(find.text('1 tente'), findsOneWidget);
  });

  testWidgets('pluralizes a multi-word label with its explicit plural', (
    tester,
  ) async {
    await tester.pumpWidget(
      _badge(
        const CountBadge(
          count: 2,
          label: 'modèle de pièce',
          pluralLabel: 'modèles de pièce',
        ),
      ),
    );

    expect(find.text('2 modèles de pièce'), findsOneWidget);
  });

  testWidgets('keeps a multi-word label singular for one', (tester) async {
    await tester.pumpWidget(
      _badge(
        const CountBadge(
          count: 1,
          label: 'modèle de tente',
          pluralLabel: 'modèles de tente',
        ),
      ),
    );

    expect(find.text('1 modèle de tente'), findsOneWidget);
  });
}

Widget _badge(CountBadge badge) {
  return MaterialApp(
    theme: AppTheme.minimal(),
    home: Scaffold(body: badge),
  );
}
