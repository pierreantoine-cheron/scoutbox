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

  static const double card = 0;
  static const double appBar = 1;
  static const double sheet = 4;
  static const double fab = 6;
  static const double dropdown = 8;
  static const double modal = 8;
}

class DesignConstants {
  DesignConstants._();

  static const searchDebounce = Duration(milliseconds: 300);

  static const fadeDoneIconDuration = Duration(milliseconds: 1600);

  static const tokenRefreshWindow = Duration(minutes: 5);

  static const clockSkewTolerance = Duration(seconds: 30);
}
