import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(this._result);

  final AuthInitializationResult _result;

  @override
  Future<AuthInitializationResult> initializeFromStorage() async {
    return _result;
  }

  @override
  Future<String?> getAccessToken() async {
    return 'token';
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
        overrides: [authServiceProvider.overrideWith((ref) => fake)],
        child: const ScoutBoxApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
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
        overrides: [authServiceProvider.overrideWith((ref) => fake)],
        child: const ScoutBoxApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Inscription'), findsOneWidget);
  });
}
