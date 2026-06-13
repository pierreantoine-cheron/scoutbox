import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final double? width;
  final bool filled;
  final Color? fillColor;

  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Rechercher...',
    this.width,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final textField = TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          },
        ),
        isDense: true,
        filled: filled,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: filled ? BorderSide.none : const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: filled ? BorderSide.none : const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.scoutGreen),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: textField);
    }

    return textField;
  }
}
