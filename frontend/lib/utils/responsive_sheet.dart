import 'package:flutter/material.dart';

import 'design_constants.dart';

const double _desktopBreakpoint = 900;
const double _dialogWidth = 480;
const double _dialogMaxHeightFactor = 0.85;

Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  bool isScrollControlled = true,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _dialogWidth),
            child: Material(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      _dialogMaxHeightFactor,
                ),
                child: builder(dialogContext),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}
