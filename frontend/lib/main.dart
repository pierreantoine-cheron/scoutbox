import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'navigation/app_router.dart';
import 'providers/providers.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ScoutBoxApp()));
}

class ScoutBoxApp extends ConsumerStatefulWidget {
  const ScoutBoxApp({super.key});

  @override
  ConsumerState<ScoutBoxApp> createState() => _ScoutBoxAppState();
}

class _ScoutBoxAppState extends ConsumerState<ScoutBoxApp> with WidgetsBindingObserver {
  final _routerDelegate = AppRouterDelegate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routerDelegate.dispose();
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
      await initializeDateFormatting('fr_FR');
    } catch (e) {
      debugPrint('Date formatting initialization failed: $e');
    }
    try {
      await ref.read(authProvider.notifier).initializeAuth();
    } catch (e) {
      debugPrint('Auth initialization failed: $e');
    }
    if (mounted) {
      _routerDelegate.completeInitialization();
    }
  }

  Future<void> _handleAppResume() async {
    await ref.read(authProvider.notifier).handleAppResume();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);

    return MaterialApp.router(
      title: 'ScoutBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(context),
      routerDelegate: _routerDelegate,
      routeInformationParser: const AppRouteInformationParser(),
    );
  }
}
