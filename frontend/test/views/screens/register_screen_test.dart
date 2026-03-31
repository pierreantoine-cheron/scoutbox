import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/screens/register_screen.dart';

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
      expect(find.text("S'inscrire"), findsOneWidget);
      expect(find.text('Déjà un compte ? Se connecter'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
    });

    testWidgets('password visibility toggles are tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.tap(find.byTooltip('Afficher le mot de passe').first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('shows error for empty server URL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

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

      await tester.enterText(
        find.widgetWithText(TextFormField, 'URL du serveur'),
        'invalid-url',
      );

      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(
        find.text("L'URL doit commencer par http:// ou https://"),
        findsOneWidget,
      );
    });

    testWidgets('invite code field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      // Verify the field exists and can receive input
      await tester.enterText(
        find.widgetWithText(TextFormField, "Code d'invitation"),
        'TESTCODE123',
      );
      await tester.pump();

      // Verify the text was entered
      expect(find.text('TESTCODE123'), findsOneWidget);
    });

    testWidgets('shows error for short password', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'short',
      );

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

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'different123',
      );

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

      // Type in server URL field - this should NOT trigger validation on other fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'URL du serveur'),
        'http',
      );
      await tester.pump();

      // No validation errors should be visible yet
      expect(find.text("L'URL du serveur est requise"), findsNothing);
      expect(find.text("Le code d'invitation est requis"), findsNothing);
      expect(find.text("Le nom d'utilisateur est requis"), findsNothing);
      expect(find.text('Le mot de passe est requis'), findsNothing);

      // Now submit the form
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      // Validation errors should now be visible
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
