import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/constants.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberUsername = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    final serverUrl = await SecureStorageService.getServerUrl();
    final rememberedUsername =
        await SecureStorageService.getRememberedUsername();
    final rememberPref =
        await SecureStorageService.getRememberUsernamePreference();

    if (!mounted) {
      return;
    }

    setState(() {
      _serverController.text = serverUrl ?? '';
      _usernameController.text = rememberedUsername ?? '';
      _rememberUsername = rememberPref;
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorCode == ErrorCodes.invalidCredentials) {
        _passwordController.clear();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'URL du serveur',
                hintText: 'https://votre-serveur.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "L'URL du serveur est requise";
                }
                if (!value.startsWith('http://') &&
                    !value.startsWith('https://')) {
                  return "L'URL doit commencer par http:// ou https://";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Nom d'utilisateur",
                border: OutlineInputBorder(),
              ),
              maxLength: ValidationConstants.usernameMaxLength,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Le nom d'utilisateur est requis";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscurePassword
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le mot de passe est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _rememberUsername,
              contentPadding: EdgeInsets.zero,
              title: const Text('Se souvenir de moi'),
              onChanged: authState.isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _rememberUsername = value ?? false;
                      });
                    },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text("Pas de compte ? S'inscrire"),
            ),
            if (authState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  authState.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authProvider.notifier)
        .login(
          serverUrl: _serverController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          rememberUsername: _rememberUsername,
        );
  }
}
