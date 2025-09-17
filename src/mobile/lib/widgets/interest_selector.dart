import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class InterestSelector extends StatelessWidget {
  final List<String> selectedInterests;
  final ValueChanged<List<String>> onChanged;

  const InterestSelector({
    super.key,
    required this.selectedInterests,
    required this.onChanged,
  });

  static const List<Map<String, dynamic>> _interests = [
    {'name': 'History', 'icon': Icons.museum},
    {'name': 'Art', 'icon': Icons.palette},
    {'name': 'Food', 'icon': Icons.restaurant},
    {'name': 'Shopping', 'icon': Icons.shopping_bag},
    {'name': 'Nature', 'icon': Icons.park},
    {'name': 'Architecture', 'icon': Icons.account_balance},
    {'name': 'Nightlife', 'icon': Icons.nightlife},
    {'name': 'Culture', 'icon': Icons.theater_comedy},
    {'name': 'Sports', 'icon': Icons.sports_soccer},
    {'name': 'Music', 'icon': Icons.music_note},
    {'name': 'Photography', 'icon': Icons.camera_alt},
    {'name': 'Markets', 'icon': Icons.storefront},
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.whatInterestsYou,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((interest) {
                final isSelected = selectedInterests.contains(interest['name']);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest['name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          interest['icon'],
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getInterestDisplayName(context, interest['name']),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (selectedInterests.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.pleaseSelectAtLeastOneInterest,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleInterest(String interest) {
    final newInterests = List<String>.from(selectedInterests);
    if (newInterests.contains(interest)) {
      newInterests.remove(interest);
    } else {
      newInterests.add(interest);
    }
    onChanged(newInterests);
  }

  String _getInterestDisplayName(BuildContext context, String interest) {
    final localizations = AppLocalizations.of(context)!;
    switch (interest) {
      case 'History':
        return localizations.interestHistory;
      case 'Art':
        return localizations.interestArt;
      case 'Food':
        return localizations.interestFood;
      case 'Shopping':
        return localizations.interestShopping;
      case 'Nature':
        return localizations.interestNature;
      case 'Architecture':
        return localizations.interestArchitecture;
      case 'Nightlife':
        return localizations.interestNightlife;
      case 'Culture':
        return localizations.interestCulture;
      case 'Sports':
        return localizations.interestSports;
      case 'Music':
        return localizations.interestMusic;
      case 'Photography':
        return localizations.interestPhotography;
      case 'Markets':
        return localizations.interestMarkets;
      default:
        return interest; // Fallback to original name
    }
  }
}