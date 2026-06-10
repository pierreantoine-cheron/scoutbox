import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/views/screens/login_screen.dart';

class _FakeAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

void main() {
  group('LoginScreen', () {
    testWidgets('displays all login form fields and actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      expect(find.text('ScoutBox'), findsOneWidget);
      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Inscription'), findsOneWidget);
      expect(find.text('URL du serveur *'), findsOneWidget);
      expect(find.text("Nom d'utilisateur *"), findsOneWidget);
      expect(find.text('Mot de passe *'), findsOneWidget);
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('shows validation when server url is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsOneWidget);
    });

    testWidgets('shows validation for short username', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'ab');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');

      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(
        find.text("Le nom d'utilisateur doit contenir au moins 3 caractères"),
        findsOneWidget,
      );
    });

    testWidgets('shows validation for short password', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');

      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(
        find.text('Le mot de passe doit contenir au moins 8 caractères'),
        findsOneWidget,
      );
    });

    testWidgets('shows success indicator after logout', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await container.read(authProvider.notifier).logout();
      await tester.pump();
      await tester.pump();

      expect(find.text('Déconnexion réussie'), findsOneWidget);
      expect(container.read(authProvider).logoutSuccessMessage, isNull);
    });
  });
}
