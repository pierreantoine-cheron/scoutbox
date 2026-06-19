import 'package:flutter/material.dart';

class FormAutovalidate {
  bool _attempted = false;

  AutovalidateMode get mode =>
      _attempted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled;

  bool markAttempted() {
    if (_attempted) return false;
    _attempted = true;
    return true;
  }

  void reset() {
    _attempted = false;
  }
}
