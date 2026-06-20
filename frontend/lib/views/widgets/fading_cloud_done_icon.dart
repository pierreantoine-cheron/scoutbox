import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/app_theme_context.dart';
import '../../utils/design_constants.dart';

class FadingCloudDoneIcon extends StatefulWidget {
  final int trigger;

  final Duration fadeDuration;

  final Duration visibleDuration;

  const FadingCloudDoneIcon({
    super.key,
    required this.trigger,
    this.fadeDuration = const Duration(milliseconds: 400),
    this.visibleDuration = DesignConstants.fadeDoneIconDuration,
  });

  @override
  State<FadingCloudDoneIcon> createState() => _FadingCloudDoneIconState();
}

class _FadingCloudDoneIconState extends State<FadingCloudDoneIcon> {
  int? _lastTrigger;
  bool _visible = false;
  Timer? _fadeTimer;

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lastTrigger == null) {
      _lastTrigger = widget.trigger;
    } else if (widget.trigger != _lastTrigger) {
      _lastTrigger = widget.trigger;
      _visible = true;
    }

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: widget.fadeDuration,
      onEnd: () {
        if (_visible) {
          _fadeTimer?.cancel();
          _fadeTimer = Timer(widget.visibleDuration, () {
            if (mounted) setState(() => _visible = false);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          Icons.cloud_done,
          color: context.semanticColors.success,
        ),
      ),
    );
  }
}
