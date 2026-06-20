import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'confirm_dialog.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Se déconnecter',
      onPressed: isLoading ? null : () => _showLogoutConfirmationDialog(context, ref),
    );
  }

  Future<void> _showLogoutConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      content: 'Votre session sera fermée.',
      confirmLabel: 'Déconnecter',
    );
    if (confirmed && context.mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
