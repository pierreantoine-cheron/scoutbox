import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../models/auth_state.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/auth_validators.dart';
import '../../utils/constants.dart';
import '../../utils/design_constants.dart';
import '../../utils/form_autovalidate.dart';
import '../widgets/primary_submit_button.dart';
import '../widgets/field_label.dart';
import '../widgets/password_form_field.dart';

enum AuthMode { login, register }

class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode initialMode;

  const AuthScreen({super.key, this.initialMode = AuthMode.login});

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

  late AuthMode _mode;
  bool _rememberMe = false;
  final _autovalidate = FormAutovalidate();

  bool get _isLogin => _mode == AuthMode.login;

  String get _submitLabel => _isLogin ? 'Se connecter' : "S'inscrire";

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _loadInitialValues();
    _serverController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _inviteController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _isFormValid {
    if (_serverController.text.trim().isEmpty) return false;
    if (_usernameController.text.trim().isEmpty) return false;
    if (_passwordController.text.isEmpty) return false;
    if (!_isLogin) {
      if (_inviteController.text.trim().isEmpty) return false;
      if (_confirmPasswordController.text.isEmpty) return false;
    }
    return true;
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
          _rememberMe = rememberPref;
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

  void _switchMode(AuthMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _autovalidate.reset();
    });
    _formKey.currentState?.reset();
    if (mode == AuthMode.login) {
      ref.read(authProvider.notifier).showLoginScreen();
    } else {
      ref.read(authProvider.notifier).showRegisterScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorCode == ErrorCodes.invalidCredentials && next.error != null) {
        _passwordController.clear();
      }
      if (next.logoutSuccessMessage != null &&
          previous?.logoutSuccessMessage != next.logoutSuccessMessage) {
        ref.read(authProvider.notifier).consumeLogoutSuccessMessage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: AppColors.surface),
                const SizedBox(width: AppSpacing.sm),
                Text(next.logoutSuccessMessage!),
              ],
            ),
            backgroundColor: AppColors.scoutGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 480;

              return SingleChildScrollView(
                padding: isDesktop ? const EdgeInsets.all(20) : EdgeInsets.zero,
                child: _buildAuthCard(isDesktop, authState),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(bool isDesktop, AuthState authState) {
    return Container(
      constraints: BoxConstraints(
        minHeight: isDesktop ? 0 : MediaQuery.of(context).size.height,
        maxWidth: isDesktop ? 400 : double.infinity,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: isDesktop ? Border.all(color: AppColors.border, width: 1) : null,
        borderRadius: isDesktop ? BorderRadius.circular(AppRadii.xl) : null,
      ),
      padding: const EdgeInsets.only(
        top: 32,
        left: 24,
        right: 24,
        bottom: 28,
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.min,
            children: [
              _buildLogoAndTitle(),
              const SizedBox(height: 28),
              _buildModeToggle(),
              const SizedBox(height: 24),
              _buildServerField(),
              const SizedBox(height: AppSpacing.md),
              if (!_isLogin) ...[
                _buildInviteField(),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildUsernameField(),
              const SizedBox(height: AppSpacing.md),
              _buildPasswordField(),
              if (!_isLogin) ...[
                const SizedBox(height: AppSpacing.md),
                _buildConfirmPasswordField(),
              ],
              if (_isLogin) ...[
                const SizedBox(height: AppSpacing.md),
                _buildRememberMe(authState.isLoading),
              ],
              if (authState.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildErrorBanner(authState.error!),
              ],
              const SizedBox(height: AppSpacing.md),
              PrimarySubmitButton(
                label: _submitLabel,
                isLoading: authState.isLoading,
                enabled: _isFormValid,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoAndTitle() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.scoutGreen,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: const Icon(Icons.grid_view, color: AppColors.surface, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          'ScoutBox',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.33,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.foreground.withAlpha(0x0D),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Connexion',
            isActive: _isLogin,
            onTap: () => _switchMode(AuthMode.login),
          ),
          _ToggleButton(
            label: 'Inscription',
            isActive: !_isLogin,
            onTap: () => _switchMode(AuthMode.register),
          ),
        ],
      ),
    );
  }

  Widget _buildServerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('URL du serveur', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _serverController,
          focusNode: _serverFocusNode,
          autovalidateMode: _autovalidate.mode,
          decoration: const InputDecoration(hintText: 'https://votre-serveur.com'),
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.validateServerUrl,
        ),
      ],
    );
  }

  Widget _buildInviteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel("Code d'invitation", required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _inviteController,
          focusNode: _inviteFocusNode,
          autovalidateMode: _autovalidate.mode,
          decoration: const InputDecoration(hintText: 'Entrez votre code'),
          maxLength: ValidationConstants.inviteCodeMaxLength,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.validateInviteCode,
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel("Nom d'utilisateur", required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          autovalidateMode: _autovalidate.mode,
          decoration: const InputDecoration(
            hintText: 'Votre nom d\'utilisateur',
          ),
          autofillHints: const [AutofillHints.username],
          maxLength: ValidationConstants.usernameMaxLength,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.validateUsername,
        ),
        if (!_isLogin)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '3 à 50 caractères',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Mot de passe', required: true),
        const SizedBox(height: 6),
        PasswordFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          autovalidateMode: _autovalidate.mode,
          hintText: _isLogin ? 'Mot de passe' : '8 caractères minimum',
          autofillHints: _isLogin ? null : const [AutofillHints.newPassword],
          textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: _isLogin ? (_) => _submit() : null,
          onEditingComplete: _isLogin ? null : () => _confirmPasswordFocusNode.requestFocus(),
          validator: AuthValidators.validatePassword,
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Confirmer le mot de passe', required: true),
        const SizedBox(height: 6),
        PasswordFormField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          autovalidateMode: _autovalidate.mode,
          hintText: 'Répétez le mot de passe',
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
      ],
    );
  }

  Widget _buildRememberMe(bool isLoading) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _rememberMe ? AppColors.scoutGreen : AppColors.border,
                width: 2,
              ),
              color: _rememberMe ? AppColors.scoutGreen : Colors.transparent,
            ),
            child: _rememberMe ? const Icon(Icons.check, color: AppColors.surface, size: 13) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
          child: Text(
            'Se souvenir de moi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_autovalidate.markAttempted()) setState(() {});

    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await ref
          .read(authProvider.notifier)
          .login(
            serverUrl: _serverController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            rememberUsername: _rememberMe,
          );
    } else {
      await ref
          .read(authProvider.notifier)
          .register(
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

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md - 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md - 2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.foreground : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
