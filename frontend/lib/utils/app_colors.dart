import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const scoutGreen = Color(0xFF2E7D32);
  static const success = scoutGreen;
  static const warningContainer = Color(0xFFFFE0B2);
  static const onWarningContainer = Color(0xFFE65100);
}

class TagPaletteOption {
  final String label;
  final String hex;
  final Color color;

  const TagPaletteOption({
    required this.label,
    required this.hex,
    required this.color,
  });
}

class TagPalette {
  TagPalette._();

  static const defaultColor = '#2196F3';

  static const options = [
    TagPaletteOption(label: 'Rouge', hex: '#F44336', color: Color(0xFFF44336)),
    TagPaletteOption(label: 'Orange', hex: '#FF9800', color: Color(0xFFFF9800)),
    TagPaletteOption(label: 'Jaune', hex: '#FFC107', color: Color(0xFFFFC107)),
    TagPaletteOption(label: 'Vert', hex: '#4CAF50', color: Color(0xFF4CAF50)),
    TagPaletteOption(label: 'Bleu', hex: '#2196F3', color: Color(0xFF2196F3)),
    TagPaletteOption(label: 'Violet', hex: '#9C27B0', color: Color(0xFF9C27B0)),
    TagPaletteOption(label: 'Rose', hex: '#E91E63', color: Color(0xFFE91E63)),
    TagPaletteOption(
      label: 'Turquoise',
      hex: '#009688',
      color: Color(0xFF009688),
    ),
    TagPaletteOption(label: 'Gris', hex: '#9E9E9E', color: Color(0xFF9E9E9E)),
    TagPaletteOption(label: 'Marron', hex: '#795548', color: Color(0xFF795548)),
  ];

  static Color colorFromHex(String hex) {
    for (final option in options) {
      if (option.hex == hex) return option.color;
    }
    return const Color(0xFF2196F3);
  }
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
