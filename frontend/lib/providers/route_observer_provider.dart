import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routeObserverProvider = Provider<RouteObserver<ModalRoute<dynamic>>>((ref) {
  return RouteObserver<ModalRoute<dynamic>>();
});
