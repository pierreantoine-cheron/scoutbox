import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../views/widgets/widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'tent_list_screen.dart';

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
            ? BackButton(onPressed: () => _navigatorKey.currentState?.pop())
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
