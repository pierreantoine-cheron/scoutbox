import 'package:flutter/material.dart';

enum NavigationSection {
  tents,
  tags,
  parts,
  models,
  journal,
  settings;

  String get label {
    return switch (this) {
      tents => 'Tentes',
      tags => 'Étiquettes',
      parts => 'Modèles de pièce',
      models => 'Modèles de tente',
      journal => 'Journal',
      settings => 'Réglages',
    };
  }

  IconData get icon {
    return switch (this) {
      tents => Icons.cabin,
      tags => Icons.label_outline,
      parts => Icons.build_outlined,
      models => Icons.grid_view_outlined,
      journal => Icons.history,
      settings => Icons.settings_outlined,
    };
  }
}
