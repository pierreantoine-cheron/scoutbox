import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData theme(BuildContext context) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.scoutGreen),
      extensions: const [
        AppSemanticColors(
          success: AppColors.success,
          warningContainer: AppColors.warningContainer,
          onWarningContainer: AppColors.onWarningContainer,
        ),
      ],
      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  static ThemeData minimal() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.scoutGreen),
      extensions: const [
        AppSemanticColors(
          success: AppColors.success,
          warningContainer: AppColors.warningContainer,
          onWarningContainer: AppColors.onWarningContainer,
        ),
      ],
      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
    );
  }
}
