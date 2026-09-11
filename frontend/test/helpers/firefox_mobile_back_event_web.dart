import 'package:web/web.dart' as web;

void dispatchFirefoxMobileBackEvent() {
  web.window.dispatchEvent(web.Event('scoutbox-firefox-back'));
}
