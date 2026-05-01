import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'views/screens/login_screen.dart';
import 'views/screens/register_screen.dart';
import 'views/screens/tent_list_screen.dart';
import 'views/widgets/fading_cloud_done_icon.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ScoutBoxApp()));
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final RouteObserver<ModalRoute<dynamic>> _routeObserver;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(routeObserverProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final appBarConfig = ref.watch(appBarConfigProvider);
    final successTrigger = ref.watch(successIndicatorProvider);

    return Scaffold(
      appBar: AppBar(
        leading: appBarConfig.showBackButton
            ? BackButton(
                onPressed: () => _navigatorKey.currentState?.pop(),
              )
            : null,
        title: appBarConfig.title,
        actions: [
          FadingCloudDoneIcon(trigger: successTrigger),
          if (appBarConfig.actions != null) ...appBarConfig.actions!,
        ],
      ),
      floatingActionButton: appBarConfig.fab,
      body: authState.isAuthenticated
          ? Navigator(
              key: _navigatorKey,
              observers: [_routeObserver],
              onGenerateInitialRoutes: (navigator, initialRoute) {
                return [
                  MaterialPageRoute(builder: (_) => const TentListScreen()),
                ];
              },
            )
          : authState.showLoginScreen
              ? const LoginScreen()
              : const RegisterScreen(),
    );
  }
}

class ScoutBoxApp extends ConsumerStatefulWidget {
  const ScoutBoxApp({super.key});

  @override
  ConsumerState<ScoutBoxApp> createState() => _ScoutBoxAppState();
}

class _ScoutBoxAppState extends ConsumerState<ScoutBoxApp>
    with WidgetsBindingObserver {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResume().catchError((e) {
        debugPrint('App resume handler failed: $e');
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      await ref.read(authProvider.notifier).initializeAuth();
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
    }
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _handleAppResume() async {
    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.handleAppResume();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);

    if (_isInitializing) {
      return MaterialApp(
        title: 'ScoutBox',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'ScoutBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
