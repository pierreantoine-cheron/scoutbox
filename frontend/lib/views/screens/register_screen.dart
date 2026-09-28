import 'package:flutter/material.dart';

import '../../models/auth_state.dart';
import 'auth_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialMode: AuthMode.register);
  }
}
