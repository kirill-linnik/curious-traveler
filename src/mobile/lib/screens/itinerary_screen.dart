import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';
import '../providers/itinerary_provider.dart';
import '../providers/enhanced_location_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/location_card.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/azure_maps_widget.dart';
import '../widgets/journey_timeline_widget.dart';
import '../widgets/info_banner.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedLocationIndex = 0;
  Set<String> _nearbyStopIds = {};
  Set<String> _tappedStopIds = {}; // Track manually tapped stops
  Timer? _locationMonitoringTimer;
  static const double _proximityRadiusMeters = 50.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startLocationMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationMonitoringTimer?.cancel();
    super.dispose();
  }

  void _startLocationMonitoring() {
    // Monitor location every 5 seconds
    _locationMonitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkProximityToStops();
    });
    
    // Defer initial check until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceLocationUpdate();
    });
  }

  Future<void> _forceLocationUpdate() async {
    if (!mounted) return;
    
    final locationProvider = context.read<EnhancedLocationProvider>();
    
    // Force a fresh location detection
    print('DEBUG: Forcing location update...');
    await locationProvider.refreshCurrentLocation();
    
    // Then check proximity
    _checkProximityToStops();
  }

  Future<void> _checkProximityToStops() async {
    if (!mounted) return;
    
    final locationProvider = context.read<EnhancedLocationProvider>();
    final itineraryProvider = context.read<ItineraryProvider>();
    
    final currentLocation = locationProvider.currentLocation;
    final currentResult = itineraryProvider.currentResult;
    
    print('DEBUG: Location monitoring check:');
    print('  - Current location: ${currentLocation?.latitude}, ${currentLocation?.longitude}');
    print('  - Has itinerary result: ${currentResult != null}');
    
    if (currentLocation == null) {
      print('DEBUG: No current location available');
      return;
    }
    
    if (currentResult == null) {
      print('DEBUG: No itinerary result available');
      return;
    }
    
    print('DEBUG: Checking ${currentResult.stops.length} stops for proximity');
    
    Set<String> newNearbyStops = {};
    
    try {
      for (final stop in currentResult.stops) {
        final stopLocation = Location(
          latitude: stop.lat,
          longitude: stop.lon,
          address: stop.address,
        );
        
        final distance = await locationProvider.getDistanceBetween(currentLocation, stopLocation);
        
        print('DEBUG: Distance to ${stop.name} (${stop.id}): ${distance.toStringAsFixed(1)}m');
        
        if (distance <= _proximityRadiusMeters) {
          newNearbyStops.add(stop.id);
          print('DEBUG: *** User is within ${distance.toStringAsFixed(1)}m of ${stop.name} - HIGHLIGHTING! ***');
        }
      }
    } catch (e) {
      print('DEBUG: Error calculating distances: $e');
    }
    
    print('DEBUG: Found ${newNearbyStops.length} nearby stops: ${newNearbyStops.toList()}');
    
    if (mounted && newNearbyStops != _nearbyStopIds) {
      setState(() {
        _nearbyStopIds = newNearbyStops;
      });
      print('DEBUG: Updated nearby stops state');
    }
  }

  void _onStopTapped(String stopId) {
    setState(() {
      if (_tappedStopIds.contains(stopId)) {
        _tappedStopIds.remove(stopId); // Toggle off if already tapped
      } else {
        _tappedStopIds.add(stopId); // Toggle on
      }
    });
    print('DEBUG: Stop $stopId tapped, now showing description');
  }

  Set<String> _getVisibleStopIds() {
    // Combine nearby stops (from GPS) and tapped stops
    return {..._nearbyStopIds, ..._tappedStopIds};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.yourItinerary),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.timeline), text: 'Journey'),
            Tab(icon: const Icon(Icons.list), text: AppLocalizations.of(context)!.listView),
            Tab(icon: const Icon(Icons.map), text: AppLocalizations.of(context)!.mapView),
          ],
        ),
      ),
      body: Consumer<ItineraryProvider>(
        builder: (context, itineraryProvider, child) {
          if (itineraryProvider.currentItinerary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noItineraryYet,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.generateFromExploreTab,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final locations = itineraryProvider.sortedLocations;

          return Column(
            children: [
              // Itinerary Summary
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.locationsCount(locations.length),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppLocalizations.of(context)!.totalTimeDisplay(
                              itineraryProvider.currentItinerary!.totalDuration ~/ 60,
                              itineraryProvider.currentItinerary!.totalDuration % 60,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      itineraryProvider.currentItinerary!.commuteStyle == 'walking'
                          ? Icons.directions_walk
                          : itineraryProvider.currentItinerary!.commuteStyle == 'transit'
                              ? Icons.directions_transit
                              : Icons.directions_car,
                      size: 32,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Journey Timeline View
                    JourneyTimelineWidget(
                      result: itineraryProvider.currentResult,
                      legacyItinerary: itineraryProvider.currentItinerary,
                      nearbyStopIds: _getVisibleStopIds(), // Pass both nearby and tapped stops
                      onStopTapped: _onStopTapped, // Add tap callback
                      startAddress: itineraryProvider.originalStartAddress, // Pass actual start address
                      endAddress: itineraryProvider.originalEndAddress, // Pass actual end address
                    ),
                    // List View
                    _buildListView(locations, itineraryProvider),
                    // Map View
                    _buildMapView(locations),
                  ],
                ),
              ),

              // Audio Player
              const AudioPlayerWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(List<ItineraryLocation> locations, ItineraryProvider itineraryProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return LocationCard(
          location: location,
          isSelected: _selectedLocationIndex == index,
          onTap: () => setState(() => _selectedLocationIndex = index),
          onFeedback: (feedback) => _handleFeedback(location.id, feedback, itineraryProvider),
        );
      },
    );
  }

  Widget _buildMapView(List<ItineraryLocation> locations) {
    if (locations.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noLocationsToDisplay),
      );
    }

    return AzureMapsWidget(
      locations: locations,
      onLocationTapped: (location) {
        // Dismiss any existing banners when selecting a new location
        InfoBannerService.dismiss();
        
        setState(() {
          _selectedLocationIndex = locations.indexOf(location);
        });
        
        _showLocationDetails(location);
      },
    );
  }

  void _showLocationDetails(ItineraryLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      location.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                location.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context)!.locationMinutes(location.duration)),
                  const SizedBox(width: 16),
                  Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(location.category),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _playNarration(location),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(AppLocalizations.of(context)!.playNarration),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playNarration(ItineraryLocation location) async {
    final itineraryProvider = context.read<ItineraryProvider>();
    final audioProvider = context.read<AudioProvider>();
    
    try {
      final narration = await itineraryProvider.getLocationNarration(location.id);
      await audioProvider.playNarration(location.id, narration);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToPlayNarration(e.toString()))),
        );
      }
    }
  }

  Future<void> _handleFeedback(String locationId, FeedbackType feedback, ItineraryProvider itineraryProvider) async {
    await itineraryProvider.updateItinerary(
      locationId: locationId,
      feedback: feedback,
    );

    if (mounted && itineraryProvider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.itineraryUpdated),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}