import 'package:flutter/material.dart';

import 'app_colors.dart';

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors {
    final colors = Theme.of(this).extension<AppSemanticColors>();

    assert(
      colors != null,
      'AppSemanticColors is missing from ThemeData.extensions',
    );

    return colors!;
  }
}
