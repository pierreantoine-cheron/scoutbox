import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('displays all login form fields and actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      expect(find.text('URL du serveur'), findsOneWidget);
      expect(find.text("Nom d'utilisateur"), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text("Pas de compte ? S'inscrire"), findsOneWidget);
    });

    testWidgets('shows validation when server url is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsOneWidget);
    });
  });
}
