import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/invite_message.dart';

import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
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
  String? _inviteLink;
  bool _isGenerating = false;
  bool _isSharing = false;

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
          _inviteLink = invite.inviteLink;
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

  Future<void> _shareMessage() async {
    final inviteLink = _inviteLink;
    final code = _generatedCode;
    if (inviteLink == null || code == null) return;

    setState(() => _isSharing = true);

    try {
      final serverUrl = await ref.read(authServiceProvider).getServerUrl();
      if (serverUrl == null || serverUrl.trim().isEmpty) {
        if (mounted) {
          showErrorDialog(
            context,
            'Impossible de partager le message : serveur inconnu.',
          );
        }
        return;
      }

      final message = composeInviteMessage(
        serverUrl: serverUrl.trim(),
        inviteCode: code,
      );

      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message copié !'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await SharePlus.instance
            .share(ShareParams(text: message))
            .timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        showErrorDialog(
          context,
          'Impossible de partager le message. Réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
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

    final isDesktop = MediaQuery.sizeOf(context).width >= DesignConstants.desktopBreakpoint;

    return Material(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: isDesktop
              ? Center(
                  child: SizedBox(
                    width: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildContent(colorScheme),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildContent(colorScheme),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(ColorScheme colorScheme) {
    return [
      const SectionLabel(
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
      const SectionLabel(
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
      if (_generatedCode != null && _inviteLink != null) ...[
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
                    fontSize: 17,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Le code expire après 30 jours et ne peut être utilisé qu\'une seule fois.',
          style: AppTheme.monoCaption,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: (_isSharing || _isGenerating) ? null : _shareMessage,
          icon: _isSharing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share, size: 18),
          label: const Text('Partager'),
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
      const SectionLabel(
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
    ];
  }
}

