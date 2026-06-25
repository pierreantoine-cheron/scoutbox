import 'package:flutter/material.dart';

import '../../models/tent_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';

class ModelSelectDropdown extends StatefulWidget {
  final List<TentModel> models;
  final TentModel? selectedModel;
  final ValueChanged<TentModel> onSelect;

  const ModelSelectDropdown({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onSelect,
  });

  @override
  State<ModelSelectDropdown> createState() => _ModelSelectDropdownState();
}

class _ModelSelectDropdownState extends State<ModelSelectDropdown> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _controller.hide();
      setState(() => _isOpen = false);
    } else {
      _controller.show();
      setState(() => _isOpen = true);
    }
  }

  void _select(TentModel model) {
    widget.onSelect(model);
    _controller.hide();
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              width: double.infinity,
              padding: AppPadding.inputField,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isOpen ? colorScheme.primary : colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(AppRadii.md),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedModel?.name ?? 'Choisir un modèle',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.selectedModel != null
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        OverlayPortal(
          controller: _controller,
          overlayChildBuilder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _controller.hide();
              setState(() => _isOpen = false);
            },
            child: Stack(
              children: [
                Positioned(
                  width: _link.leaderSize?.width,
                  child: CompositedTransformFollower(
                    link: _link,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: const Offset(0, 4),
                    child: _buildDropdownList(colorScheme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownList(ColorScheme colorScheme) {
    return Material(
      elevation: AppElevation.popup,
      borderRadius: BorderRadius.circular(AppRadii.md),
      shadowColor: colorScheme.shadow.withAlpha(30),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.md),
          color: colorScheme.surface,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: widget.models.map((m) {
            final isSelected = widget.selectedModel?.id == m.id;
            return InkWell(
              onTap: () => _select(m),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                color: isSelected ? AppColors.accentSoft : null,
                child: Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.scoutGreen : colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
