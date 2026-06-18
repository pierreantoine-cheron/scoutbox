import 'package:flutter/material.dart';

import 'state_badge.dart';

enum ScoutPillVariant { full, compact }

class ScoutPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final ScoutPillVariant variant;
  final Border? baseBorder;
  final Color? selectedBorderColor;
  final List<BoxShadow>? selectedBoxShadow;
  final String? tooltip;
  final String? semanticLabel;

  const ScoutPill._({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.onTap,
    this.selected = false,
    this.variant = ScoutPillVariant.full,
    this.baseBorder,
    this.selectedBorderColor,
    this.selectedBoxShadow,
    this.tooltip,
    this.semanticLabel,
  });

  const ScoutPill.tag({
    Key? key,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool selected = false,
    String? tooltip,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          onTap: onTap,
          selected: selected,
          variant: ScoutPillVariant.full,
          selectedBorderColor: Colors.white,
          tooltip: tooltip,
          semanticLabel: semanticLabel,
        );

  const ScoutPill.tagCompact({
    Key? key,
    required String label,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          onTap: onTap,
          variant: ScoutPillVariant.compact,
          tooltip: tooltip,
          semanticLabel: semanticLabel,
        );

  ScoutPill.tagFilter({
    Key? key,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool selected = false,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          onTap: onTap,
          selected: selected,
          variant: ScoutPillVariant.full,
          semanticLabel: semanticLabel,
        );

  ScoutPill.state({
    Key? key,
    required StateBadgeStyle style,
    VoidCallback? onTap,
    bool selected = false,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: style.label,
          backgroundColor: style.background,
          foregroundColor: style.foreground,
          icon: style.icon,
          onTap: onTap,
          selected: selected,
          variant: ScoutPillVariant.full,
          semanticLabel: semanticLabel,
        );

  ScoutPill.stateCompact({
    Key? key,
    required StateBadgeStyle style,
    VoidCallback? onTap,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: style.label,
          backgroundColor: style.background,
          foregroundColor: style.foreground,
          icon: style.icon,
          onTap: onTap,
          variant: ScoutPillVariant.compact,
          semanticLabel: semanticLabel,
        );

  const ScoutPill.filterState({
    Key? key,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    VoidCallback? onTap,
    bool selected = false,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          onTap: onTap,
          selected: selected,
          variant: ScoutPillVariant.full,
        );

  const ScoutPill.filterNeutral({
    Key? key,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    VoidCallback? onTap,
    bool selected = false,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          onTap: onTap,
          selected: selected,
          variant: ScoutPillVariant.full,
        );

  ScoutPill.neutral({
    Key? key,
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required Color borderColor,
    VoidCallback? onTap,
    String? semanticLabel,
  }) : this._(
          key: key,
          label: label,
          backgroundColor: Colors.transparent,
          foregroundColor: foregroundColor,
          icon: icon,
          baseBorder: Border.all(color: borderColor),
          onTap: onTap,
          variant: ScoutPillVariant.full,
          semanticLabel: semanticLabel,
        );

  @override
  Widget build(BuildContext context) {
    final isFull = variant == ScoutPillVariant.full;
    final hPad = isFull ? 12.0 : 10.0;
    final vPad = isFull ? 6.0 : 4.0;
    final fontSize = isFull ? 14.0 : 11.0;
    final iconSize = isFull ? 16.0 : 12.0;
    final iconGap = isFull ? 6.0 : 5.0;
    final fontWeight = isFull ? FontWeight.w500 : FontWeight.w600;

    final effectiveBorder = isFull
        ? (baseBorder ??
            Border.all(
              color: selected
                  ? (selectedBorderColor ?? foregroundColor)
                  : Colors.transparent,
              width: 2.0,
            ))
        : baseBorder;

    final effectiveShadows =
        (selected && isFull) ? selectedBoxShadow : null;

    Widget pill = Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: effectiveBorder,
        boxShadow: effectiveShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: foregroundColor),
            SizedBox(width: iconGap),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      pill = InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: pill,
      );
    }

    if (semanticLabel != null) {
      pill = Semantics(
        label: semanticLabel!,
        button: onTap != null,
        child: ExcludeSemantics(child: pill),
      );
    }

    if (tooltip != null) {
      pill = Tooltip(message: tooltip!, child: pill);
    }

    return pill;
  }
}
