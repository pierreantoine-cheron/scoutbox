import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const scoutGreen = Color(0xFF186A23);
  static const accentSoft = Color(0x1F186A23); // scoutGreen at 12% opacity
  static const success = scoutGreen;

  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);

  static const foreground = Color(0xFF11171C);
  static const muted = Color(0xFF646A70);

  static const border = Color(0xFFDEE2E5);

  static const surfaceContainerLow = Color(0xFFF3F4F6);
  static const surfaceContainer = Color(0xFFEDEEF0);
  static const surfaceContainerHigh = Color(0xFFE7E8EA);
  static const surfaceContainerHighest = Color(0xFFE1E2E4);

  static const statePerfect = Color(0xFF1D9330);
  static const statePerfectBackground = Color(0xFFDBF3DB);

  static const stateUsable = Color(0xFFC68D21);
  static const stateUsableBackground = Color(0xFFFFEBC1);

  static const stateUnusable = Color(0xFFC91519);
  static const stateUnusableBackground = Color(0xFFFFDCD7);

  static const stateMissing = Color(0xFF6A57B3);
  static const stateMissingBackground = Color(0xFFECE2FF);

  static const error = stateUnusable;
  static const errorBackground = Color(0xFFFFE2DE);
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

  static const defaultColor = '#1A70E5';

  static const options = [
    TagPaletteOption(label: 'Rouge', hex: '#DF202E', color: Color(0xFFDF202E)),
    TagPaletteOption(label: 'Orange', hex: '#DD7234', color: Color(0xFFDD7234)),
    TagPaletteOption(label: 'Jaune', hex: '#C6A136', color: Color(0xFFC6A136)),
    TagPaletteOption(label: 'Vert', hex: '#1D9330', color: Color(0xFF1D9330)),
    TagPaletteOption(label: 'Bleu', hex: '#1A70E5', color: Color(0xFF1A70E5)),
    TagPaletteOption(label: 'Violet', hex: '#6A34AB', color: Color(0xFF6A34AB)),
    TagPaletteOption(label: 'Rose', hex: '#C91B86', color: Color(0xFFC91B86)),
    TagPaletteOption(
      label: 'Turquoise',
      hex: '#43857F',
      color: Color(0xFF43857F),
    ),
    TagPaletteOption(label: 'Gris', hex: '#6D7277', color: Color(0xFF6D7277)),
    TagPaletteOption(label: 'Marron', hex: '#6D411C', color: Color(0xFF6D411C)),
  ];

  static Color colorFromHex(String hex) {
    for (final option in options) {
      if (option.hex == hex) return option.color;
    }
    debugPrint(
      'TagPalette: unknown color hex "$hex", falling back to default blue',
    );
    return const Color(0xFF1A70E5);
  }

  static Color textColorFor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
  }
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color statePerfect;
  final Color statePerfectBackground;
  final Color stateUsable;
  final Color stateUsableBackground;
  final Color stateUnusable;
  final Color stateUnusableBackground;
  final Color stateMissing;
  final Color stateMissingBackground;

  const AppSemanticColors({
    required this.success,
    required this.statePerfect,
    required this.statePerfectBackground,
    required this.stateUsable,
    required this.stateUsableBackground,
    required this.stateUnusable,
    required this.stateUnusableBackground,
    required this.stateMissing,
    required this.stateMissingBackground,
  });

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? statePerfect,
    Color? statePerfectBackground,
    Color? stateUsable,
    Color? stateUsableBackground,
    Color? stateUnusable,
    Color? stateUnusableBackground,
    Color? stateMissing,
    Color? stateMissingBackground,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      statePerfect: statePerfect ?? this.statePerfect,
      statePerfectBackground:
          statePerfectBackground ?? this.statePerfectBackground,
      stateUsable: stateUsable ?? this.stateUsable,
      stateUsableBackground:
          stateUsableBackground ?? this.stateUsableBackground,
      stateUnusable: stateUnusable ?? this.stateUnusable,
      stateUnusableBackground:
          stateUnusableBackground ?? this.stateUnusableBackground,
      stateMissing: stateMissing ?? this.stateMissing,
      stateMissingBackground:
          stateMissingBackground ?? this.stateMissingBackground,
    );
  }

  @override
  AppSemanticColors lerp(
    ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;

    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      statePerfect: Color.lerp(statePerfect, other.statePerfect, t)!,
      statePerfectBackground: Color.lerp(
        statePerfectBackground,
        other.statePerfectBackground,
        t,
      )!,
      stateUsable: Color.lerp(stateUsable, other.stateUsable, t)!,
      stateUsableBackground: Color.lerp(
        stateUsableBackground,
        other.stateUsableBackground,
        t,
      )!,
      stateUnusable: Color.lerp(
        stateUnusable,
        other.stateUnusable,
        t,
      )!,
      stateUnusableBackground: Color.lerp(
        stateUnusableBackground,
        other.stateUnusableBackground,
        t,
      )!,
      stateMissing: Color.lerp(stateMissing, other.stateMissing, t)!,
      stateMissingBackground: Color.lerp(
        stateMissingBackground,
        other.stateMissingBackground,
        t,
      )!,
    );
  }
}
