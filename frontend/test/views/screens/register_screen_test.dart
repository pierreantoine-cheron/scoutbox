import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/deep_link_service.dart';
import 'package:client/providers/deep_link_provider.dart';
import 'package:client/views/screens/register_screen.dart';

class _FakeDeepLinkService extends DeepLinkService {
  Uri? _initialLink;
  bool _initialConsumed = false;
  Completer<void>? initialLinkGate;
  final _streamController = StreamController<Uri>();

  @override
  Stream<Uri> get uriLinkStream => _streamController.stream;

  @override
  Future<Uri?> getInitialLink() async {
    if (_initialConsumed) return null;
    final gate = initialLinkGate;
    if (gate != null) {
      await gate.future;
    }
    final link = _initialLink;
    if (link == null || DeepLinkService.isConsumed(link)) return null;
    _initialConsumed = true;
    DeepLinkService.consumeLink(link);
    return link;
  }

  void setInitialLink(Uri? uri) {
    _initialLink = uri;
  }

  void emit(Uri uri) {
    _streamController.add(uri);
  }

  Future<void> dispose() async {
    await _streamController.close();
  }
}

void main() {
  group('RegisterScreen', () {
    testWidgets('displays all form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RegisterScreen())),
      );

      expect(find.text('URL du serveur *'), findsOneWidget);
      expect(find.text("Code d'invitation *"), findsOneWidget);
      expect(find.text("Nom d'utilisateur *"), findsOneWidget);
      expect(find.text('Mot de passe *'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe *'), findsOneWidget);
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

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'INVITE123');
      await tester.enterText(find.byType(TextFormField).at(2), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '');
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
      await tester.enterText(find.byType(TextFormField).at(1), 'INVITE123');
      await tester.enterText(find.byType(TextFormField).at(2), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');

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

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'INVITE123');
      await tester.enterText(find.byType(TextFormField).at(2), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(3), 'short');
      await tester.enterText(find.byType(TextFormField).at(4), 'short');

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

      await tester.enterText(find.byType(TextFormField).at(0), 'https://api.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'INVITE123');
      await tester.enterText(find.byType(TextFormField).at(2), 'testuser');
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
      await tester.enterText(find.byType(TextFormField).at(1), 'INVITE123');
      await tester.enterText(find.byType(TextFormField).at(2), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(3), 'password123');
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');
      await tester.pump();

      expect(find.text("L'URL du serveur est requise"), findsNothing);
      expect(find.text("Le code d'invitation est requis"), findsNothing);
      expect(find.text("Le nom d'utilisateur est requis"), findsNothing);
      expect(find.text('Le mot de passe est requis'), findsNothing);

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();

      expect(
        find.text("L'URL doit commencer par http:// ou https://"),
        findsOneWidget,
      );
      expect(find.text("Le code d'invitation est requis"), findsNothing);
      expect(find.text("Le nom d'utilisateur est requis"), findsNothing);
      expect(find.text('Le mot de passe est requis'), findsNothing);
    });
  });

  group('RegisterScreen deep link prefill', () {
    testWidgets('prefills server and invite fields from deep link data', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      fakeService.setInitialLink(
        Uri.parse('scoutbox://register?server=https://deep-test.groupe.fr&invite=DEEP-2024'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('https://deep-test.groupe.fr'), findsOneWidget);
      expect(find.text('DEEP-2024'), findsOneWidget);
    });

    testWidgets('shows confirmation snackbar when deep link data is loaded', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      fakeService.setInitialLink(
        Uri.parse('scoutbox://register?server=https://test.groupe.fr&invite=SNACK-123'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsOneWidget,
      );
    });

    testWidgets('fields remain editable after deep link prefill', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      fakeService.setInitialLink(
        Uri.parse('scoutbox://register?server=https://original.groupe.fr&invite=ORIG-CODE'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'https://edited.groupe.fr');
      await tester.enterText(find.byType(TextFormField).at(1), 'EDITED-CODE');

      await tester.pump();

      expect(find.text('https://edited.groupe.fr'), findsOneWidget);
      expect(find.text('EDITED-CODE'), findsOneWidget);
    });

    testWidgets('shows warning and leaves fields empty for incomplete deep link', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      fakeService.setInitialLink(
        Uri.parse('scoutbox://register?server=https://missing-invite.groupe.fr'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Le lien d'invitation est incomplet"), findsOneWidget);
      expect(find.text('https://missing-invite.groupe.fr'), findsNothing);
      expect(tester.widget<EditableText>(find.byType(EditableText).at(0)).controller.text, isEmpty);
      expect(tester.widget<EditableText>(find.byType(EditableText).at(1)).controller.text, isEmpty);
    });

    testWidgets('does not replay initial link snackbar when switching to login', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      final uri = Uri.parse(
        'scoutbox://register?server=https://replay.groupe.fr&invite=REPLAY-CODE',
      );
      fakeService.setInitialLink(uri);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsNothing,
      );

      fakeService.emit(uri);
      await tester.ensureVisible(find.text('Connexion').first);
      await tester.tap(find.text('Connexion').first);
      await tester.pumpAndSettle();

      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsNothing,
      );
    });

    testWidgets('does not queue second snackbar when stream beats initial link', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeDeepLinkService();
      addTearDown(fakeService.dispose);
      final gate = Completer<void>();
      final uri = Uri.parse(
        'scoutbox://register?server=https://race.groupe.fr&invite=RACE-CODE',
      );
      fakeService
        ..initialLinkGate = gate
        ..setInitialLink(uri);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepLinkServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pump();
      fakeService.emit(uri);
      await tester.pumpAndSettle();
      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsOneWidget,
      );

      gate.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(
        find.text("Serveur et code d'invitation préremplis depuis le lien"),
        findsNothing,
      );
    });
  });
}
