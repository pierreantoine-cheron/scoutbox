import 'package:flutter/material.dart';

class ScoutChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final String? semanticLabel;
  final int? maxLines;
  final TextOverflow? overflow;
  final double fontSize;

  const ScoutChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onTap,
    this.border,
    this.boxShadow,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.tooltip,
    this.semanticLabel,
    this.maxLines,
    this.overflow,
    this.fontSize = 13,
  });

  const ScoutChip.tag({
    Key? key,
    required String label,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
    String? semanticLabel,
  }) : this(
          key: key,
          label: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          fontSize: 12,
          tooltip: tooltip,
          semanticLabel: semanticLabel,
        );

  ScoutChip.filter({
    Key? key,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required bool selected,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          border: selected
              ? Border.all(color: foregroundColor, width: 1.5)
              : null,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        );

  ScoutChip.filterTag({
    Key? key,
    required String name,
    required Color color,
    required bool selected,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: name,
          backgroundColor: color,
          foregroundColor: Colors.white,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: selected ? 2 : 0,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color, spreadRadius: 2)]
              : null,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          fontSize: 12,
        );

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: border,
        boxShadow: boxShadow,
      ),
      child: Text(
        label,
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: foregroundColor,
        ),
      ),
    );

    Widget result = chip;

    if (onTap != null) {
      result = InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: result,
      );
    }

    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: ExcludeSemantics(child: result),
      );
    }

    if (tooltip != null) {
      result = Tooltip(
        message: tooltip!,
        child: result,
      );
    }

    return result;
  }
}
