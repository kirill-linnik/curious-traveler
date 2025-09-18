import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';
import '../models/location_models.dart';
import '../providers/itinerary_provider.dart';
import '../providers/enhanced_location_provider.dart';
import '../services/api_service.dart';
import '../viewmodels/home_location_vm.dart';
import '../widgets/interest_selector.dart';
import '../widgets/commute_selector.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/location_search_input.dart';
import '../widgets/info_banner.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CommuteStyle _selectedCommuteStyle = CommuteStyle.walking;
  int _duration = 4; // hours
  List<String> _selectedInterests = [];
  String _language = 'en-US';
  
  // Use new dual-block HomeLocationVm
  late final HomeLocationVm _locationVm;
  
  EnhancedLocationProvider? _locationProvider;
  ApiService? _apiService;
  
  // Track if we've performed initial location detection
  bool _hasInitializedLocation = false;

  @override
  void initState() {
    super.initState();
    _locationVm = HomeLocationVm();
    _loadPreferences();
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_handleLocationProviderChanges);
    _locationVm.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize services and providers on home screen load (one-shot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationProvider = context.read<EnhancedLocationProvider>();
      _apiService = context.read<ApiService>();
      
      // Set the API service in the VM
      _locationVm.setApiService(_apiService!);
      
      // Only detect location once per Home screen instance
      if (!_hasInitializedLocation) {
        _locationProvider!.detectCurrentLocation();
        _hasInitializedLocation = true;
      }
      
      // Add listener to handle location provider changes
      _locationProvider!.addListener(_handleLocationProviderChanges);
    });
  }

  void _handleLocationProviderChanges() {
    final locationProvider = _locationProvider;
    
    // Guard clause for safety
    if (locationProvider == null || !mounted) return;

    // Let the ViewModel handle provider changes for legacy compatibility
    _locationVm.handleProviderChange(locationProvider);

    // Show info banners based on location status changes
    switch (locationProvider.status) {
      case LocationStatus.detecting:
        InfoBannerService.showLocationDetecting(context);
        break;
      case LocationStatus.detected:
        // Only show "Location found" banner for GPS detection (current location mode)
        if (locationProvider.mode == LocationMode.currentLocation) {
          InfoBannerService.showLocationFound(context);
        }
        break;
      case LocationStatus.failed:
        InfoBannerService.showLocationFailed(context);
        break;
      default:
        break;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = context.read<SharedPreferences>();
    setState(() {
      _language = prefs.getString('language') ?? 'en-US';
      _duration = prefs.getInt('default_duration') ?? 4;
      _selectedInterests = prefs.getStringList('interests') ?? [];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = context.read<SharedPreferences>();
    await prefs.setString('language', _language);
    await prefs.setInt('default_duration', _duration);
    await prefs.setStringList('interests', _selectedInterests);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer2<ItineraryProvider, EnhancedLocationProvider>(
        builder: (context, itineraryProvider, locationProvider, child) {
          // Check if we should automatically switch to itinerary tab
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && 
                itineraryProvider.jobStatus == JobStatus.completed && 
                itineraryProvider.hasItinerary) {
              print('DEBUG: Job reached final state: JobStatus.completed <- switching to itinerary tab automatically');
              
              // Use global key to switch to itinerary tab (index 1)
              mainNavigatorKey.currentState?.switchToTab(1);
            }
          });
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.welcomeTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.welcomeDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // START OF JOURNEY BLOCK
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.homeTitleStartOfJourney,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        
                        ListenableBuilder(
                          listenable: _locationVm.start,
                          builder: (context, _) {
                            return SegmentedToggle(
                              value: _locationVm.start.mode,
                              onChanged: (mode) => _locationVm.start.setMode(
                                mode,
                                currentSnapshot: _locationVm.currentLocationSnapshot,
                              ),
                              labels: [
                                localizations.homeToggleCurrentLocation,
                                localizations.homeToggleAnotherLocation,
                              ],
                            );
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        ListenableBuilder(
                          listenable: _locationVm.start,
                          builder: (context, _) {
                            return LocationSearchInput(
                              endpointState: _locationVm.start,
                              enabled: _locationVm.start.mode == LocationMode.anotherLocation,
                              onSearch: _locationVm.searchLocations,
                              onSuggestionTap: (selection, ctx) => 
                                  _locationVm.start.onSuggestionSelected(selection, ctx),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // END OF JOURNEY BLOCK
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.homeTitleEndOfJourney,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        
                        ListenableBuilder(
                          listenable: _locationVm.end,
                          builder: (context, _) {
                            return SegmentedToggle(
                              value: _locationVm.end.mode,
                              onChanged: (mode) => _locationVm.end.setMode(
                                mode,
                                currentSnapshot: _locationVm.currentLocationSnapshot,
                              ),
                              labels: [
                                localizations.homeToggleCurrentLocation,
                                localizations.homeToggleAnotherLocation,
                              ],
                            );
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        ListenableBuilder(
                          listenable: _locationVm.end,
                          builder: (context, _) {
                            return LocationSearchInput(
                              endpointState: _locationVm.end,
                              enabled: _locationVm.end.mode == LocationMode.anotherLocation,
                              onSearch: _locationVm.searchLocations,
                              onSuggestionTap: (selection, ctx) => 
                                  _locationVm.end.onSuggestionSelected(selection, ctx),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Interests Section
                InterestSelector(
                  selectedInterests: _selectedInterests,
                  onChanged: (interests) {
                    setState(() {
                      _selectedInterests = interests;
                    });
                    _savePreferences();
                  },
                ),

                const SizedBox(height: 24),

                // Commute Section
                CommuteSelector(
                  selectedStyle: _selectedCommuteStyle,
                  onChanged: (style) {
                    setState(() {
                      _selectedCommuteStyle = style;
                    });
                    _savePreferences();
                  },
                ),

                const SizedBox(height: 24),

                // Duration Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.durationHours(_duration),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _duration.toDouble(),
                          min: 1,
                          max: 12,
                          divisions: 11,
                          label: localizations.durationHours(_duration),
                          onChanged: (value) {
                            setState(() {
                              _duration = value.round();
                            });
                            _savePreferences();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Generate Button
                ElevatedButton(
                  onPressed: _canGenerate() ? () => _generateItinerary(itineraryProvider) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: itineraryProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(localizations.generateItinerary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _canGenerate() {
    return _selectedInterests.isNotEmpty && 
           _duration > 0 &&
           _locationVm.hasStartPoint &&
           _locationVm.hasEndPoint;
  }

  void _generateItinerary(ItineraryProvider itineraryProvider) async {
    final localizations = AppLocalizations.of(context)!;
    
    print('DEBUG: _generateItinerary called');
    
    // Dismiss any existing banners first
    InfoBannerService.dismiss();
    
    try {
      // Get both start and end coordinates for the new job-based API
      final startCoords = _locationVm.startCoords;
      final endCoords = _locationVm.endCoords;
      
      print('DEBUG: Start coords: $startCoords');
      print('DEBUG: End coords: $endCoords');
      
      if (startCoords == null) {
        print('DEBUG: No start location selected');
        InfoBannerService.show(
          context: context,
          message: localizations.selectStartLocation,
          type: InfoBannerType.error,
        );
        return;
      }
      
      if (endCoords == null) {
        print('DEBUG: No end location selected');
        InfoBannerService.show(
          context: context,
          message: localizations.selectEndLocation,
          type: InfoBannerType.error,
        );
        return;
      }

      // Create LocationPoint objects for the job request
      final startPoint = LocationPoint(
        lat: startCoords.lat,
        lon: startCoords.lon,
        address: _locationVm.start.displayText,
      );
      
      final endPoint = LocationPoint(
        lat: endCoords.lat,
        lon: endCoords.lon,
        address: _locationVm.end.displayText,
      );

      print('DEBUG: Start point: ${startPoint.toJson()}');
      print('DEBUG: End point: ${endPoint.toJson()}');
      print('DEBUG: Interests: $_selectedInterests');
      print('DEBUG: Duration: $_duration hours');

      // Convert CommuteStyle to TravelMode
      final travelMode = TravelModeExtension.fromCommuteStyle(_selectedCommuteStyle);
      print('DEBUG: Travel mode: $travelMode');

      // Use the new job-based API with 2-character language code
      print('DEBUG: Calling generateItineraryWithJob...');
      await itineraryProvider.generateItineraryWithJob(
        start: startPoint,
        end: endPoint,
        interests: _selectedInterests,
        mode: travelMode,
        durationHours: _duration,
        language: _language.substring(0, 2), // Use only first 2 characters (en-US -> en)
      );

      print('DEBUG: generateItineraryWithJob completed successfully');
      // Navigation will be handled automatically when the job completes
      // The provider will update the UI through listeners
      
    } catch (e, stackTrace) {
      print('DEBUG: Error in _generateItinerary: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        InfoBannerService.show(
          context: context,
          message: '${localizations.itineraryJobCreateFailed}\n\nError: $e',
          type: InfoBannerType.error,
        );
      }
    }
  }
}