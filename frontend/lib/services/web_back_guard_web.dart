import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebBackGuard {
  JSFunction? _popStateListener;

  void initialize(void Function() onBack) {
    _pushGuard();
    _popStateListener = ((web.Event _) {
      _pushGuard();
      onBack();
    }).toJS;
    web.window.addEventListener('popstate', _popStateListener);
  }

  void dispose() {
    final listener = _popStateListener;
    if (listener != null) {
      web.window.removeEventListener('popstate', listener);
      _popStateListener = null;
    }
  }

  void _pushGuard() {
    web.window.history.pushState(
      web.window.history.state,
      '',
      web.window.location.href,
    );
  }
}
