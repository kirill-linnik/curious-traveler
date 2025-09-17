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

                const SizedBox(height: 24),

                // END OF JOURNEY BLOCK
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

                const SizedBox(height: 32),

                // Interests Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.whatInterestsYou,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        InterestSelector(
                          selectedInterests: _selectedInterests,
                          onChanged: (interests) {
                            setState(() {
                              _selectedInterests = interests;
                            });
                            _savePreferences();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Commute Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.howWillYouGetAround,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        CommuteSelector(
                          selectedStyle: _selectedCommuteStyle,
                          onChanged: (style) {
                            setState(() {
                              _selectedCommuteStyle = style;
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
    // Dismiss any existing banners first
    InfoBannerService.dismiss();
    
    try {
      // For now, use the start location as the target for itinerary generation
      // In the future, this will be updated to use both start and end coordinates
      final startCoords = _locationVm.startCoords;
      if (startCoords == null) {
        InfoBannerService.show(
          context: context,
          message: 'Please select a start location',
          type: InfoBannerType.error,
        );
        return;
      }

      // Create a dummy location result for the current API
      final targetLocation = LocationSearchResult(
        id: 'start_location',
        type: 'Location',
        name: 'Start Location',
        formattedAddress: _locationVm.start.displayText,
        locality: '',
        countryCode: '',
        latitude: startCoords.lat,
        longitude: startCoords.lon,
        confidence: 'high',
      );

      await itineraryProvider.generateItinerary(
        city: targetLocation.name,
        interests: _selectedInterests,
        commuteStyle: _selectedCommuteStyle,
        duration: _duration,
        language: _language,
      );

      if (mounted && itineraryProvider.currentItinerary != null) {
        Navigator.pushNamed(
          context,
          '/itinerary',
          arguments: itineraryProvider.currentItinerary,
        );
      }
    } catch (e) {
      if (mounted) {
        InfoBannerService.show(
          context: context,
          message: 'Failed to generate itinerary. Please try again.',
          type: InfoBannerType.error,
        );
      }
    }
  }
}