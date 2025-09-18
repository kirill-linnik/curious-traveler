import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';

/// Widget that displays the itinerary journey in a timeline format
/// showing start → stop 1 → stop 2 → ... → end with travel and visit times
class JourneyTimelineWidget extends StatelessWidget {
  final ItineraryResult? result;
  final Itinerary? legacyItinerary;
  final Set<String> nearbyStopIds; // Stop IDs that should show descriptions (GPS proximity)
  final Function(String stopId)? onStopTapped; // Callback for when a stop is tapped
  final String? startAddress; // Actual start address from home screen
  final String? endAddress; // Actual end address from home screen

  const JourneyTimelineWidget({
    super.key,
    this.result,
    this.legacyItinerary,
    this.nearbyStopIds = const {},
    this.onStopTapped,
    this.startAddress,
    this.endAddress,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    if (result != null) {
      return _buildNewFormatTimeline(context, result!, localizations);
    } else if (legacyItinerary != null) {
      return _buildLegacyFormatTimeline(context, legacyItinerary!, localizations);
    } else {
      return Center(
        child: Text(localizations.noLocationsToDisplay),
      );
    }
  }

  Widget _buildNewFormatTimeline(BuildContext context, ItineraryResult result, AppLocalizations localizations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Journey summary
          _buildSummaryCard(context, result.summary, localizations),
          
          const SizedBox(height: 16),
          
          // Journey timeline
          _buildJourneySteps(context, result, localizations),
        ],
      ),
    );
  }

  Widget _buildLegacyFormatTimeline(BuildContext context, Itinerary itinerary, AppLocalizations localizations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legacy format - convert to timeline view
          ...itinerary.locations.asMap().entries.map((entry) {
            final index = entry.key;
            final location = entry.value;
            final isLast = index == itinerary.locations.length - 1;
            
            return _buildLegacyLocationStep(context, location, isLast, localizations);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ItinerarySummary summary, AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journey Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(summary.mode.icon, size: 20),
                const SizedBox(width: 8),
                Text(summary.mode.displayName),
              ],
            ),
            const SizedBox(height: 4),
            Text('Total travel: ${summary.totalTravelMinutes} minutes'),
            Text('Total visit: ${summary.totalVisitMinutes} minutes'),
            Text('Total distance: ${(summary.totalDistanceMeters / 1000).toStringAsFixed(1)} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneySteps(BuildContext context, ItineraryResult result, AppLocalizations localizations) {
    final stops = result.stops;
    final legs = result.legs;
    
    // Use provided addresses if available, otherwise fall back to legs data
    final startLocation = startAddress ?? (legs.isNotEmpty ? legs.first.from : 'Start');
    final endLocation = endAddress ?? (legs.isNotEmpty ? legs.last.to : 'End');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Journey',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        
        // Build the complete journey: Start → Stop 1 → Stop 2 → ... → End
        Column(
          children: [
            // Start location
            _buildStartEndStep(
              context: context,
              locationName: startLocation,
              isStart: true,
              leg: null, // START doesn't show travel time
              localizations: localizations,
            ),
            if (stops.isNotEmpty) _buildArrow(),
            
            // Intermediate stops
            ...stops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              final isLast = index == stops.length - 1;
              // Travel time should come from the leg that leads TO this stop (index 0 is START→STOP1, index 1 is STOP1→STOP2, etc.)
              final incomingLeg = index < legs.length ? legs[index] : null;
              
              return Column(
                children: [
                  _buildJourneyStep(
                    context: context,
                    stop: stop,
                    incomingLeg: incomingLeg, // Pass the leg that leads TO this stop
                    isFirst: false,
                    isLast: false,
                    stopNumber: index + 1,
                    showDescription: nearbyStopIds.contains(stop.id),
                    localizations: localizations,
                    onStopTapped: onStopTapped,
                  ),
                  if (!isLast || legs.length > stops.length) _buildArrow(),
                ],
              );
            }).toList(),
            
            // End location (only if we have legs indicating an end)
            if (legs.length > stops.length)
              _buildStartEndStep(
                context: context,
                locationName: endLocation,
                isStart: false,
                leg: legs.isNotEmpty ? legs.last : null, // Pass the last leg for END travel time
                localizations: localizations,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildJourneyStep({
    required BuildContext context,
    required ItineraryStop stop,
    required ItineraryLeg? incomingLeg, // Changed from 'leg' to 'incomingLeg' for clarity
    required bool isFirst,
    required bool isLast,
    required int stopNumber,
    required bool showDescription, // Whether to show description based on GPS proximity
    required AppLocalizations localizations,
    required Function(String stopId)? onStopTapped, // Add tap callback
  }) {
    return GestureDetector(
      onTap: onStopTapped != null ? () => onStopTapped(stop.id) : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: showDescription 
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) // Highlighted background for nearby stops
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showDescription 
                ? Theme.of(context).colorScheme.primary // Highlighted border for nearby stops
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: showDescription ? 2 : 1,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Travel info BEFORE location (showing how we arrived here)
          if (incomingLeg != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk, // This should be dynamic based on travel mode
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.arriveInMinutes(incomingLeg.travelMinutes),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(incomingLeg.distanceMeters / 1000).toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Location info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'STOP $stopNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      stop.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Description (only shown when GPS proximity is detected)
          if (showDescription && stop.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1,
                ),
              ),
              child: Text(
                stop.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          
          if (stop.visitMinutes > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                localizations.spendMinutes(stop.visitMinutes),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          
          // Travel info for next leg (REMOVED - no longer needed at bottom)
        ], // End of Column children
      ), // End of Column
    ), // End of Container
    ); // End of GestureDetector
  }

  Widget _buildStartEndStep({
    required BuildContext context,
    required String locationName,
    required bool isStart,
    required ItineraryLeg? leg,
    required AppLocalizations localizations,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Travel info BEFORE END location (showing how we arrived at END)
          if (leg != null && !isStart) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_walk, // This should be dynamic based on travel mode
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.arriveInMinutes(leg.travelMinutes),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(leg.distanceMeters / 1000).toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Location info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isStart ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isStart ? 'START' : 'END',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locationName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyLocationStep(BuildContext context, ItineraryLocation location, bool isLast, AppLocalizations localizations) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(location.location.address),
          if (location.duration > 0)
            Text(localizations.spendMinutes(location.duration)),
          if (location.travelTime > 0 && !isLast)
            Text(localizations.arriveInMinutes(location.travelTime)),
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_downward,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }
}