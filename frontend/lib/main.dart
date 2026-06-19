import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/providers.dart';
import 'utils/app_theme.dart';
import 'views/screens/auth_gate.dart';
import 'views/widgets/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ScoutBoxApp()));
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
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _handleAppResume() async {
    await ref.read(authProvider.notifier).handleAppResume();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);

    if (_isInitializing) {
      return MaterialApp(
        title: 'ScoutBox',
        theme: AppTheme.minimal(),
        home: const Scaffold(body: Center(child: AppProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'ScoutBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(context),
      home: const AuthGate(),
    );
  }
}
