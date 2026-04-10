import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/auth_validators.dart';
import '../../utils/constants.dart';
import '../widgets/password_form_field.dart';

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
  final _serverFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _rememberUsername = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final message = ref.read(authProvider).logoutSuccessMessage;
      if (message != null) {
        _showLogoutSuccessMessage(message);
        ref.read(authProvider.notifier).consumeLogoutSuccessMessage();
      }
    });
  }

  Future<void> _loadInitialValues() async {
    try {
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
    } catch (e) {
      // Log error but continue with empty form
      debugPrint('Failed to load saved values: $e');
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorCode == ErrorCodes.invalidCredentials) {
        _passwordController.clear();
      }

      if (next.logoutSuccessMessage != null &&
          previous?.logoutSuccessMessage != next.logoutSuccessMessage) {
        final message = next.logoutSuccessMessage!;
        ref.read(authProvider.notifier).consumeLogoutSuccessMessage();
        _showLogoutSuccessMessage(message);
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
              focusNode: _serverFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                labelText: 'URL du serveur',
                hintText: 'https://votre-serveur.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.validateServerUrl,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                labelText: "Nom d'utilisateur",
                border: OutlineInputBorder(),
              ),
              autofillHints: const [AutofillHints.username],
              maxLength: ValidationConstants.usernameMaxLength,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.validateUsername,
            ),
            const SizedBox(height: 16),
            PasswordFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              labelText: 'Mot de passe',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: AuthValidators.validatePassword,
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
                      ref.read(authProvider.notifier).showRegisterScreen();
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
    setState(() {
      _hasSubmitted = true;
    });

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

  void _showLogoutSuccessMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
