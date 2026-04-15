import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client/main.dart';
import 'package:client/models/auth_response.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/views/screens/login_screen.dart';
import 'package:client/views/screens/register_screen.dart';
import 'package:client/views/screens/tent_list_screen.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(this._result, {this.loginSucceeds = false});

  final AuthInitializationResult _result;
  final bool loginSucceeds;

  @override
  Future<AuthInitializationResult> initializeFromStorage() async {
    return _result;
  }

  @override
  Future<String?> getAccessToken() async {
    return 'token';
  }

  @override
  Future<AuthResult> login({
    required String serverUrl,
    required String username,
    required String password,
    required bool rememberUsername,
  }) async {
    if (!loginSucceeds) {
      return AuthResult.failure(error: 'Identifiants invalides');
    }

    final now = DateTime.now();
    return AuthResult.success(
      authResponse: AuthResponse(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        accessTokenExpires: now.add(const Duration(minutes: 30)),
        refreshTokenExpires: now.add(const Duration(days: 30)),
      ),
    );
  }
}

void main() {
  testWidgets('routes to LoginScreen for returning unauthenticated users', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService(
      const AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
        shouldShowLogin: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const ScoutBoxApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('routes to RegisterScreen for first-time users', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService(
      const AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
        shouldShowLogin: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const ScoutBoxApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('transitions to TentListScreen after successful login', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService(
      const AuthInitializationResult(
        isAuthenticated: false,
        isSessionExpired: false,
        shouldShowLogin: true,
      ),
      loginSucceeds: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const ScoutBoxApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'URL du serveur'),
      'https://api.scoutbox.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Nom d'utilisateur"),
      'testuser',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'password123',
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TentListScreen), findsOneWidget);
  });
}
