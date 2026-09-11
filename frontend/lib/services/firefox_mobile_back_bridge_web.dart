import 'dart:js_interop';

import 'package:web/web.dart' as web;

class FirefoxMobileBackBridge {
  static const _eventName = 'scoutbox-firefox-back';

  JSFunction? _listener;

  void initialize(void Function() onBack) {
    _listener = ((web.Event _) => onBack()).toJS;
    web.window.addEventListener(_eventName, _listener);
  }

  void dispose() {
    final listener = _listener;
    if (listener == null) return;

    web.window.removeEventListener(_eventName, listener);
    _listener = null;
  }
}
