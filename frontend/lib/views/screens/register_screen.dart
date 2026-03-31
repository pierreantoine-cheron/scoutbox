import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/constants.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _inviteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _serverFocusNode = FocusNode();
  final _inviteFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadStoredServerUrl();
  }

  Future<void> _loadStoredServerUrl() async {
    final serverUrl = await SecureStorageService.getServerUrl();
    if (!mounted || serverUrl == null || serverUrl.isEmpty) {
      return;
    }
    _serverController.text = serverUrl;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _inviteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _serverFocusNode.dispose();
    _inviteFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
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
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
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
              controller: _inviteController,
              focusNode: _inviteFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: const InputDecoration(
                labelText: "Code d'invitation",
                border: OutlineInputBorder(),
              ),
              maxLength: ValidationConstants.inviteCodeMaxLength,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Le code d'invitation est requis";
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Le nom d'utilisateur est requis";
                }
                if (value.length < ValidationConstants.usernameMinLength) {
                  return "Le nom d'utilisateur doit contenir au moins ${ValidationConstants.usernameMinLength} caractères";
                }
                if (value.length > ValidationConstants.usernameMaxLength) {
                  return "Le nom d'utilisateur ne peut pas dépasser ${ValidationConstants.usernameMaxLength} caractères";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
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
              autofillHints: const [AutofillHints.newPassword],
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le mot de passe est requis';
                }
                if (value.length < ValidationConstants.passwordMinLength) {
                  return 'Le mot de passe doit contenir au moins ${ValidationConstants.passwordMinLength} caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  tooltip: _obscureConfirmPassword
                      ? 'Afficher la confirmation'
                      : 'Masquer la confirmation',
                ),
              ),
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer le mot de passe';
                }
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
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
                    : const Text("S'inscrire", style: TextStyle(fontSize: 16)),
              ),
            ),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
              child: const Text('Déjà un compte ? Se connecter'),
            ),
            if (authState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  authState.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
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

    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authProvider.notifier)
        .register(
          serverUrl: _serverController.text.trim(),
          inviteCode: _inviteController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }
}
