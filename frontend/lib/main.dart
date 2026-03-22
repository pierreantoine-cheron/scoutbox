import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/deep_link_service.dart';
import 'providers/auth_provider.dart';
import 'views/screens/register_screen.dart';
import 'views/screens/tent_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ScoutBoxApp()));
}

class ScoutBoxApp extends ConsumerStatefulWidget {
  const ScoutBoxApp({super.key});

  @override
  ConsumerState<ScoutBoxApp> createState() => _ScoutBoxAppState();
}

class _ScoutBoxAppState extends ConsumerState<ScoutBoxApp> {
  InviteLinkData? _initialInviteData;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check for initial deep link
    final deepLinkService = DeepLinkService();
    final initialLink = await deepLinkService.getInitialLink();
    if (initialLink != null) {
      setState(() {
        _initialInviteData = DeepLinkService.parseInviteLink(initialLink);
      });
    }

    // Check authentication status
    await ref.read(authProvider.notifier).checkAuthStatus();

    setState(() {
      _isInitializing = false;
    });

    // Listen for deep links while app is running
    deepLinkService.deepLinkStream.listen((uri) {
      final inviteData = DeepLinkService.parseInviteLink(uri);
      if (inviteData != null && mounted) {
        // Navigate to registration with prefilled data
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RegisterScreen(prefilledData: inviteData),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
      home: authState.isAuthenticated
          ? const TentListScreen()
          : RegisterScreen(prefilledData: _initialInviteData),
    );
  }
}
