import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';

class LocationCard extends StatelessWidget {
  final ItineraryLocation location;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(FeedbackType) onFeedback;

  const LocationCard({
    super.key,
    required this.location,
    required this.isSelected,
    required this.onTap,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${location.order}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          location.category.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showFeedbackDialog(context),
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                location.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Info Row
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    Icons.schedule,
                    AppLocalizations.of(context)!.locationDurationMinutes(location.duration),
                  ),
                  const SizedBox(width: 8),
                  if (location.travelTime > 0)
                    _buildInfoChip(
                      context,
                      Icons.directions_walk,
                      AppLocalizations.of(context)!.travelTimeMinutes(location.travelTime),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.howWasLocation(location.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3,
              children: FeedbackType.values.map((feedback) {
                return ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onFeedback(feedback);
                  },
                  icon: Icon(feedback.icon, size: 16),
                  label: Text(
                    _getFeedbackDisplayName(context, feedback),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeedbackDisplayName(BuildContext context, FeedbackType feedback) {
    final localizations = AppLocalizations.of(context)!;
    switch (feedback) {
      case FeedbackType.like:
        return localizations.feedbackLike;
      case FeedbackType.dislike:
        return localizations.feedbackDislike;
      case FeedbackType.moreTime:
        return localizations.feedbackMoreTime;
      case FeedbackType.lessTime:
        return localizations.feedbackLessTime;
    }
  }
}