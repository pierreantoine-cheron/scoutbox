import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/screens/register_screen.dart';

void main() {
  group('RegisterScreen', () {
    testWidgets('displays all form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      expect(find.text('URL du serveur'), findsOneWidget);
      expect(find.text("Code d'invitation"), findsOneWidget);
      expect(find.text("Nom d'utilisateur"), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.text(' *'), findsNWidgets(5));
      expect(find.text("S'inscrire"), findsOneWidget);
      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Inscription'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
    });

    testWidgets('password visibility toggles are tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.ensureVisible(find.byTooltip('Afficher le mot de passe').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Afficher le mot de passe').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('shows error for empty server URL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsOneWidget);
    });

    testWidgets('shows error for invalid server URL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'invalid-url');

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(
        find.text("L'URL doit commencer par http:// ou https://"),
        findsOneWidget,
      );
    });

    testWidgets('invite code field accepts input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(1), 'TESTCODE123');
      await tester.pump();

      expect(find.text('TESTCODE123'), findsOneWidget);
    });

    testWidgets('shows error for short password', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(3), 'short');

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(
        find.text('Le mot de passe doit contenir au moins 8 caractères'),
        findsOneWidget,
      );
    });

    testWidgets('shows error for mismatched passwords', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.enterText(find.byType(TextFormField).at(4), 'different123');

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(
        find.text('Les mots de passe ne correspondent pas'),
        findsOneWidget,
      );
    });

    testWidgets('does not show validation errors before submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'http');
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsNothing);
      expect(find.text("Le code d'invitation est requis"), findsNothing);
      expect(find.text("Le nom d'utilisateur est requis"), findsNothing);
      expect(find.text('Le mot de passe est requis'), findsNothing);

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsNothing);
      expect(
        find.text("L'URL doit commencer par http:// ou https://"),
        findsOneWidget,
      );
      expect(find.text("Le code d'invitation est requis"), findsOneWidget);
      expect(find.text("Le nom d'utilisateur est requis"), findsOneWidget);
      expect(find.text('Le mot de passe est requis'), findsOneWidget);
    });
  });
}
