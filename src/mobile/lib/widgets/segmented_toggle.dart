import 'package:flutter/material.dart';
import '../models/location_models.dart';

/// Segmented toggle widget for switching between location modes
/// Generic enough to be reused for both start and end journey blocks
class SegmentedToggle extends StatelessWidget {
  final LocationMode value;
  final ValueChanged<LocationMode> onChanged;
  final List<String> labels;

  const SegmentedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    assert(labels.length == 2, 'SegmentedToggle requires exactly 2 labels');
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              text: labels[0],
              icon: Icons.my_location,
              isSelected: value == LocationMode.currentLocation,
              onTap: () => onChanged(LocationMode.currentLocation),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              ),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              text: labels[1],
              icon: Icons.edit_location,
              isSelected: value == LocationMode.anotherLocation,
              onTap: () => onChanged(LocationMode.anotherLocation),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(7),
                bottomRight: Radius.circular(7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ToggleOption({
    required this.text,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: isSelected ? colorScheme.primary : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected 
                    ? colorScheme.onPrimary 
                    : colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected 
                        ? colorScheme.onPrimary 
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}