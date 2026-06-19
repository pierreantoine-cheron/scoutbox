import 'package:flutter/material.dart';

class FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const FieldLabel(this.label, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
