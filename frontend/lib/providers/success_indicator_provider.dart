import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuccessIndicatorNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void fire() {
    state++;
  }
}

final successIndicatorProvider =
    NotifierProvider<SuccessIndicatorNotifier, int>(
  SuccessIndicatorNotifier.new,
);
