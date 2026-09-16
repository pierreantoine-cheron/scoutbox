import 'package:web/web.dart' as web;

class BrowserNavigation {
  static bool get canGoBack => true;

  static void back() => web.window.history.back();

  static void forward() => web.window.history.forward();
}
