import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class NavigationSectionNotifier extends Notifier<NavigationSection> {
  @override
  NavigationSection build() => NavigationSection.tents;

  void set(NavigationSection section) {
    state = section;
  }
}

final navigationSectionProvider = NotifierProvider<NavigationSectionNotifier, NavigationSection>(
  NavigationSectionNotifier.new,
);
