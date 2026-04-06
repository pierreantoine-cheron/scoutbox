import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tent.dart';
import '../../providers/auth_provider.dart';
import 'tent_creation_screen.dart';

class TentListScreen extends ConsumerStatefulWidget {
  const TentListScreen({super.key});

  @override
  ConsumerState<TentListScreen> createState() => _TentListScreenState();
}

class _TentListScreenState extends ConsumerState<TentListScreen> {
  final List<Tent> _createdTents = [];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScoutBox - Tentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: authState.isLoading
                ? null
                : () => _showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Inscription réussie !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Vous êtes maintenant connecté.'),
            const SizedBox(height: 32),
            const Text(
              'Liste des tentes à venir...',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_createdTents.isEmpty)
              const Text('Aucune tente créée pour le moment.')
            else
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: _createdTents.length,
                  itemBuilder: (context, index) {
                    final tent = _createdTents[index];
                    return ListTile(
                      title: Text(tent.name),
                      subtitle: Text(
                        'Taille ${tent.size} - Etat ${tent.overallState}',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTentCreation(context),
        tooltip: 'Ajouter une tente',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openTentCreation(BuildContext context) async {
    final createdTent = await Navigator.of(
      context,
    ).push<Tent>(MaterialPageRoute(builder: (_) => const TentCreationScreen()));

    if (createdTent == null || !mounted) {
      return;
    }

    setState(() {
      _createdTents.insert(0, createdTent);
    });
  }

  void _showLogoutConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text('Votre session sera fermée.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(authProvider.notifier).logout();
              },
              child: const Text('Déconnecter'),
            ),
          ],
        );
      },
    );
  }
}
