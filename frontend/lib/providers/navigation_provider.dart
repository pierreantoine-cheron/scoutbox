import 'package:flutter/material.dart';

enum NavigationSection {
  tents,
  tags,
  parts,
  models,
  settings;

  String get label {
    return switch (this) {
      tents => 'Tentes',
      tags => 'Étiquettes',
      parts => 'Éléments',
      models => 'Modèles',
      settings => 'Réglages',
    };
  }

  IconData get icon {
    return switch (this) {
      tents => Icons.cabin,
      tags => Icons.label_outline,
      parts => Icons.build_outlined,
      models => Icons.grid_view_outlined,
      settings => Icons.settings_outlined,
    };
  }
}
