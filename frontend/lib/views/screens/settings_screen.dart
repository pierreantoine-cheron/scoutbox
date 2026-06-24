import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import '../../utils/error_messages.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _username;
  String? _generatedCode;
  bool _isGenerating = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(appBarConfigProvider.notifier)
          .set(
            const AppBarConfig(screenId: 'settings'),
          );
    });
  }

  Future<void> _loadUsername() async {
    final username = await ref.read(authServiceProvider).getCurrentUsername();
    if (mounted) {
      setState(() => _username = username);
    }
  }

  Future<void> _generateCode() async {
    setState(() => _isGenerating = true);
    try {
      final invite = await ref.read(authProvider.notifier).createInvite();
      if (mounted) {
        setState(() {
          _generatedCode = invite.code;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        showErrorDialog(
          context,
          toUserFacingError(e, 'Impossible de générer le code d\'invitation. Réessayez.'),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      content: 'Votre session sera fermée.',
      confirmLabel: 'Déconnecter',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  icon: Icons.person_outline,
                  label: "Nom d'utilisateur",
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _username ?? '—',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                  icon: Icons.lock_outline,
                  label: 'Code d\'invitation',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Générez un code pour inviter un nouvel utilisateur à rejoindre ScoutBox.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isGenerating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_generatedCode != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Text(
                            _generatedCode!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _CopyButton(
                        isCopied: _isCopied,
                        onTap: _copyToClipboard,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Le code expire après 30 jours et ne peut être utilisé qu\'une seule fois.',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateCode,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _generatedCode == null ? 'Générer un code' : 'Générer un nouveau code',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                  icon: Icons.logout,
                  label: 'Déconnexion',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Vous serez redirigé vers l\'écran d\'authentification.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _showLogoutConfirmation,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  final bool isCopied;
  final VoidCallback onTap;

  const _CopyButton({
    required this.isCopied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isCopied) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Copié !'),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: const Icon(Icons.copy, size: 16),
      label: const Text('Copier'),
    );
  }
}
