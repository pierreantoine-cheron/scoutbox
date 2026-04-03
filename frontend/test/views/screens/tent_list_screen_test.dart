import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/views/screens/tent_list_screen.dart';

void main() {
  group('TentListScreen', () {
    testWidgets('opens logout dialog and cancels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TentListScreen())),
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter ?'), findsOneWidget);
      expect(find.text('Votre session sera fermée.'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter ?'), findsNothing);
    });

    testWidgets('disables logout button while loading', (
      WidgetTester tester,
    ) async {
      const loadingState = AuthState(isLoading: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWithValue(loadingState)],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });
  });
}
