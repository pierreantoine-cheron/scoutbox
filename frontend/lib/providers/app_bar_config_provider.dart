import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBarConfig {
  final String screenId;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? fab;
  final bool showBackButton;

  const AppBarConfig({
    required this.screenId,
    this.title,
    this.actions,
    this.fab,
    this.showBackButton = false,
  });

  @override
  bool operator ==(Object other) =>
      other is AppBarConfig &&
      other.screenId == screenId &&
      other.title == title &&
      other.actions == actions &&
      other.fab == fab &&
      other.showBackButton == showBackButton;

  @override
  int get hashCode =>
      Object.hash(screenId, title, actions, fab, showBackButton);
}

class AppBarConfigNotifier extends Notifier<AppBarConfig> {
  @override
  AppBarConfig build() => const AppBarConfig(screenId: '');

  void set(AppBarConfig config) {
    state = config;
  }
}

final appBarConfigProvider =
    NotifierProvider<AppBarConfigNotifier, AppBarConfig>(
      AppBarConfigNotifier.new,
    );
