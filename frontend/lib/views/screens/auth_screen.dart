import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/auth_validators.dart';
import '../../utils/constants.dart';
import '../widgets/password_form_field.dart';

enum AuthMode { login, register }

class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode mode;

  const AuthScreen({super.key, required this.mode});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final _serverFocusNode = FocusNode();
  late final _usernameFocusNode = FocusNode();
  late final _passwordFocusNode = FocusNode();
  late final _inviteFocusNode = FocusNode();
  late final _confirmPasswordFocusNode = FocusNode();

  bool _rememberUsername = false;
  bool _hasSubmitted = false;

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
    if (_isLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = ref.read(authProvider).logoutSuccessMessage;
        if (message != null) {
          ref.read(authProvider.notifier).consumeLogoutSuccessMessage();
          ref.read(successIndicatorProvider.notifier).fire();
        }
      });
    }
  }

  Future<void> _loadInitialValues() async {
    try {
      final serverUrl = await SecureStorageService.getServerUrl();
      if (!mounted) return;
      setState(() {
        _serverController.text = serverUrl ?? '';
      });
      if (_isLogin) {
        final rememberedUsername = await SecureStorageService.getRememberedUsername();
        final rememberPref = await SecureStorageService.getRememberUsernamePreference();
        if (!mounted) return;
        setState(() {
          _usernameController.text = rememberedUsername ?? '';
          _rememberUsername = rememberPref;
        });
      }
    } catch (e) {
      debugPrint('Failed to load saved values: $e');
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _inviteController.dispose();
    _confirmPasswordController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _inviteFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (_isLogin) {
      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.errorCode == ErrorCodes.invalidCredentials) {
          _passwordController.clear();
        }
        if (next.logoutSuccessMessage != null &&
            previous?.logoutSuccessMessage != next.logoutSuccessMessage) {
          ref.read(authProvider.notifier).consumeLogoutSuccessMessage();
          ref.read(successIndicatorProvider.notifier).fire();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appBarConfigProvider.notifier).set(AppBarConfig(
          screenId: _isLogin ? 'login' : 'register',
          title: Text(_isLogin ? 'Connexion' : 'Inscription'),
        ));
      }
    });

    return Material(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildServerField(),
              const SizedBox(height: 16),
              if (!_isLogin) ...[
                _buildInviteField(),
                const SizedBox(height: 16),
              ],
              _buildUsernameField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              if (!_isLogin) ...[
                _buildConfirmPasswordField(),
                const SizedBox(height: 16),
              ],
              if (_isLogin) ...[
                _buildRememberMeCheckbox(authState.isLoading),
                const SizedBox(height: 8),
              ],
              _buildSubmitButton(authState.isLoading),
              _buildSwitchButton(authState.isLoading),
              _buildErrorDisplay(authState.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerField() {
    return TextFormField(
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
    );
  }

  Widget _buildInviteField() {
    return TextFormField(
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
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
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
    );
  }

  Widget _buildPasswordField() {
    return PasswordFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      labelText: 'Mot de passe',
      autofillHints: _isLogin ? null : const [AutofillHints.newPassword],
      textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: _isLogin ? (_) => _submit() : null,
      onEditingComplete: _isLogin
          ? null
          : () => _confirmPasswordFocusNode.requestFocus(),
      validator: AuthValidators.validatePassword,
    );
  }

  Widget _buildConfirmPasswordField() {
    return PasswordFormField(
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
    );
  }

  Widget _buildRememberMeCheckbox(bool isLoading) {
    return CheckboxListTile(
      value: _rememberUsername,
      contentPadding: EdgeInsets.zero,
      title: const Text('Se souvenir de moi'),
      onChanged: isLoading
          ? null
          : (value) {
              setState(() {
                _rememberUsername = value ?? false;
              });
            },
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isLogin ? 'Se connecter' : "S'inscrire",
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildSwitchButton(bool isLoading) {
    return TextButton(
      onPressed: isLoading
          ? null
          : () {
              if (_isLogin) {
                ref.read(authProvider.notifier).showRegisterScreen();
              } else {
                ref.read(authProvider.notifier).showLoginScreen();
              }
            },
      child: Text(
        _isLogin ? "Pas de compte ? S'inscrire" : 'Déjà un compte ? Se connecter',
      ),
    );
  }

  Widget _buildErrorDisplay(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _hasSubmitted = true;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await ref.read(authProvider.notifier).login(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rememberUsername: _rememberUsername,
      );
    } else {
      await ref.read(authProvider.notifier).register(
        serverUrl: _serverController.text.trim(),
        inviteCode: _inviteController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (mounted && ref.read(authProvider).isAuthenticated) {
      TextInput.finishAutofillContext(shouldSave: true);
    }
  }
}
