import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/auth_validators.dart';
import '../../utils/constants.dart';
import '../widgets/password_form_field.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appBarConfigProvider.notifier).set(const AppBarConfig(
          screenId: 'register',
          title: Text('Inscription'),
        ));
      }
    });

    return Material(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
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
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.validateServerUrl,
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
              validator: AuthValidators.validateInviteCode,
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onEditingComplete: () {
                _confirmPasswordFocusNode.requestFocus();
              },
              validator: AuthValidators.validatePassword,
            ),
            const SizedBox(height: 16),
            PasswordFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              autovalidateMode: _hasSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              labelText: 'Confirmer le mot de passe',
              showPasswordTooltip: 'Afficher la confirmation',
              hidePasswordTooltip: 'Masquer la confirmation',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => AuthValidators.validatePasswordMatch(
                value,
                _passwordController.text,
              ),
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
                      ref.read(authProvider.notifier).showLoginScreen();
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
    ));
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

    if (mounted && ref.read(authProvider).isAuthenticated) {
      TextInput.finishAutofillContext(shouldSave: true);
    }
  }
}
