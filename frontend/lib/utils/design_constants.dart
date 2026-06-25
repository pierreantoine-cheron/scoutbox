import 'package:flutter/widgets.dart';

class AppRadii {
  AppRadii._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
}

class AppElevation {
  AppElevation._();

  static const double popup = 8;
}

class AppPadding {
  AppPadding._();

  static const EdgeInsets inputField = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const EdgeInsets cardContent = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
}

class AppOpacity {
  AppOpacity._();

  static const double disabled = 0.55;
}

class DesignConstants {
  DesignConstants._();

  static const double desktopBreakpoint = 768.0;

  static const searchDebounce = Duration(milliseconds: 300);

  static const fadeDoneIconDuration = Duration(milliseconds: 1600);

  static const tokenRefreshWindow = Duration(minutes: 5);

  static const clockSkewTolerance = Duration(seconds: 30);
}
