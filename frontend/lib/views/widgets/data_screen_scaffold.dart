import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/error_messages.dart';
import 'app_progress_indicator.dart';
import 'async_error_view.dart';

class DataScreenScaffold<T> extends StatelessWidget {
  final AsyncValue<T> state;
  final Widget Function(T) builder;
  final String errorFallbackMessage;
  final VoidCallback? onRetry;
  final Widget? loadingPlaceholder;

  const DataScreenScaffold({
    super.key,
    required this.state,
    required this.builder,
    required this.errorFallbackMessage,
    this.onRetry,
    this.loadingPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: state.when(
          loading: () =>
              loadingPlaceholder ??
              const Center(child: AppProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            message: toUserFacingError(error, errorFallbackMessage),
            onRetry: onRetry,
          ),
          data: (data) => builder(data),
        ),
      ),
    );
  }
}
