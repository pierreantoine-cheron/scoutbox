import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/models/auth_state.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/views/screens/auth_screen.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows error banner when auth state has error', (
      WidgetTester tester,
    ) async {
      const errorState = AuthState(error: 'Identifiants incorrects.');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWithValue(errorState)],
          child: const MaterialApp(
            home: AuthScreen(initialMode: AuthMode.login),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Identifiants incorrects.'), findsOneWidget);
    });

    testWidgets('shows progress indicator and hides submit button when loading', (
      WidgetTester tester,
    ) async {
      const loadingState = AuthState(isLoading: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWithValue(loadingState)],
          child: const MaterialApp(
            home: AuthScreen(initialMode: AuthMode.login),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Se connecter'), findsNothing);
    });

    testWidgets('register mode hides remember me checkbox', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWithValue(const AuthState())],
          child: const MaterialApp(
            home: AuthScreen(initialMode: AuthMode.register),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Se souvenir de moi'), findsNothing);
      expect(find.text("S'inscrire"), findsOneWidget);
    });
  });
}
