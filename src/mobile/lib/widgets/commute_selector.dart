import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';

class CommuteSelector extends StatelessWidget {
  final CommuteStyle selectedStyle;
  final ValueChanged<CommuteStyle> onChanged;

  const CommuteSelector({
    super.key,
    required this.selectedStyle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.howWillYouGetAround,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: CommuteStyle.values.map((style) {
                final isSelected = style == selectedStyle;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onChanged(style),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              style.icon,
                              size: 32,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getCommuteDisplayName(context, style),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getCommuteDisplayName(BuildContext context, CommuteStyle style) {
    final localizations = AppLocalizations.of(context)!;
    switch (style) {
      case CommuteStyle.walking:
        return localizations.commuteWalking;
      case CommuteStyle.transit:
        return localizations.commuteTransit;
      case CommuteStyle.driving:
        return localizations.commuteDriving;
    }
  }
}