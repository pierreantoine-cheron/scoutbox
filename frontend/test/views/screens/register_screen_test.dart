import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/screens/register_screen.dart';
import 'package:frontend/services/deep_link_service.dart';

void main() {
  group('RegisterScreen', () {
    testWidgets('displays all form fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      expect(find.text('URL du serveur'), findsOneWidget);
      expect(find.text("Code d'invitation"), findsOneWidget);
      expect(find.text("Nom d'utilisateur"), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('displays confirmation card when prefilled data provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            prefilledData: InviteLinkData(
              serverUrl: 'https://example.com',
              inviteCode: 'TEST123',
            ),
          ),
        ),
      );

      expect(find.text("Données d'invitation chargées"), findsOneWidget);
    });

    testWidgets('does not display confirmation card without prefilled data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      expect(find.text("Données d'invitation chargées"), findsNothing);
    });

    testWidgets('prefills fields with invite data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            prefilledData: InviteLinkData(
              serverUrl: 'https://test-server.com',
              inviteCode: 'INVITE-123',
            ),
          ),
        ),
      );

      // Find the TextFormField widgets and check their controllers
      final serverField = find.widgetWithText(TextFormField, 'URL du serveur');
      final inviteField = find.widgetWithText(
        TextFormField,
        "Code d'invitation",
      );

      expect(serverField, findsOneWidget);
      expect(inviteField, findsOneWidget);
    });

    testWidgets('shows error for empty server URL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      // Tap the register button without filling fields
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsOneWidget);
    });

    testWidgets('shows error for invalid server URL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      // Enter invalid URL
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

    testWidgets('shows error for short password', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      // Enter short password
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
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

      // Enter different passwords
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
  });
}
