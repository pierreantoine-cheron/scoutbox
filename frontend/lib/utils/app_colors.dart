import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const scoutGreen = Color(0xFF2E7D32);
  static const success = scoutGreen;
  static const warningContainer = Color(0xFFFFE0B2);
  static const onWarningContainer = Color(0xFFE65100);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color warningContainer;
  final Color onWarningContainer;

  const AppSemanticColors({
    required this.success,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;

    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}
