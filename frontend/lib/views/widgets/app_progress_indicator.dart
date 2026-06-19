import 'package:flutter/material.dart';

class AppProgressIndicator extends StatelessWidget {
  final Color? color;

  const AppProgressIndicator({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(strokeWidth: 2, color: color);
  }
}
