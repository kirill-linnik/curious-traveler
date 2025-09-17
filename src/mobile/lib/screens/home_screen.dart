import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/itinerary_models.dart';
import '../models/location_models.dart';
import '../providers/itinerary_provider.dart';
import '../providers/enhanced_location_provider.dart';
import '../viewmodels/home_location_vm.dart';
import '../widgets/interest_selector.dart';
import '../widgets/commute_selector.dart';
import '../widgets/location_mode_toggle.dart';
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
  
  // Use HomeLocationVm for deterministic location state management
  late final HomeLocationVm _locationVm;
  
  EnhancedLocationProvider? _locationProvider;
  
  // Track if we've performed initial location detection
  bool _hasInitializedLocation = false;
  
  // Track last searched query to prevent circular calls
  String _lastSearchedQuery = '';

  @override
  void initState() {
    super.initState();
    _locationVm = HomeLocationVm();
    _loadPreferences();
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_handleLocationProviderChanges);
    _locationVm.removeListener(_handleViewModelChanges);
    _locationVm.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize current location detection on home screen load (one-shot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationProvider = context.read<EnhancedLocationProvider>();
      
      // Only detect location once per Home screen instance
      if (!_hasInitializedLocation) {
        _locationProvider!.detectCurrentLocation();
        _hasInitializedLocation = true;
      }
      
      // Add listener to handle location provider changes
      _locationProvider!.addListener(_handleLocationProviderChanges);
      
      // Add listener to handle ViewModel changes (for search)
      _locationVm.addListener(_handleViewModelChanges);
    });
  }

  void _handleLocationProviderChanges() {
    final locationProvider = _locationProvider;
    
    // Guard clause for safety
    if (locationProvider == null || !mounted) return;

    // Let the ViewModel handle provider changes
    _locationVm.handleProviderChange(locationProvider);

    // Sync search results from provider to ViewModel
    if (locationProvider.status == LocationStatus.searchComplete) {
      _locationVm.updateSearchResults(locationProvider.searchResults);
    } else if (locationProvider.status == LocationStatus.unknown) {
      _locationVm.updateSearchResults([]);
    }

    // Show info banners based on location status changes
    switch (locationProvider.status) {
      case LocationStatus.detecting:
        InfoBannerService.showLocationDetecting(context);
        break;
      case LocationStatus.detected:
      case LocationStatus.searchComplete:
        // Only show "Location found" banner for GPS detection (current location mode)
        // Don't show it for manual location searches in "another location" mode
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

  void _handleViewModelChanges() {
    final locationProvider = _locationProvider;
    
    // Guard clause for safety
    if (locationProvider == null || !mounted) return;

    // Trigger search when queryText changes in "Another Location" mode
    if (_locationVm.locationSource == LocationMode.anotherLocation) {
      final queryText = _locationVm.queryText;
      
      // Only trigger search if query has actually changed
      if (queryText != _lastSearchedQuery) {
        _lastSearchedQuery = queryText;
        
        if (queryText.isEmpty) {
          locationProvider.clearSearch();
        } else {
          locationProvider.searchLocations(queryText);
        }
      }
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



  void _handleModeChanged(LocationMode mode) {
    final provider = context.read<EnhancedLocationProvider>();
    
    // Use ViewModel for race-free mode changes and text updates
    _locationVm.handleModeChanged(mode);
    
    // Set the mode in the provider
    provider.setMode(mode);
    
    if (mode == LocationMode.currentLocation) {
      // When switching to Current location, ViewModel handles text update
      // Update selected location in provider to match current location snapshot
      if (provider.currentLocation != null && _locationVm.currentLocationSnapshot != null) {
        final snapshot = _locationVm.currentLocationSnapshot!;
        // Create a LocationSearchResult from the current location
        final currentResult = LocationSearchResult(
          id: 'current_location',
          type: 'Current',
          name: snapshot.displayText,
          formattedAddress: snapshot.displayText,
          locality: snapshot.locality ?? '',
          countryCode: '',
          latitude: snapshot.position?.latitude ?? 0.0,
          longitude: snapshot.position?.longitude ?? 0.0,
          confidence: 'high',
        );
        provider.selectLocation(currentResult);
      }
    } else if (mode == LocationMode.anotherLocation) {
      // When switching to Another location, ViewModel handles clearing
      provider.clearSearch();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
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
                          AppLocalizations.of(context)!.welcomeTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.welcomeDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Location Mode Toggle
                LocationModeToggle(
                  mode: locationProvider.mode,
                  onChanged: _handleModeChanged,
                ),
                
                const SizedBox(height: 16),
                
                // Location Input Field
                LocationSearchInput(
                  viewModel: _locationVm,
                  searchResults: locationProvider.searchResults,
                  status: locationProvider.status,
                  error: locationProvider.error,
                  enabled: locationProvider.mode == LocationMode.anotherLocation ||
                           locationProvider.status == LocationStatus.failed,
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
                          AppLocalizations.of(context)!.whatInterestsYou,
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
                          AppLocalizations.of(context)!.howWillYouGetAround,
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
                  onPressed: _canGenerate(locationProvider) ? () => _generateItinerary(itineraryProvider, locationProvider) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: itineraryProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(AppLocalizations.of(context)!.generateItinerary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _canGenerate(EnhancedLocationProvider locationProvider) {
    return _selectedInterests.isNotEmpty && 
           _duration > 0 &&
           (locationProvider.mode == LocationMode.currentLocation
               ? locationProvider.currentLocation != null
               : _locationVm.locationController.text.isNotEmpty);
  }

  void _generateItinerary(ItineraryProvider itineraryProvider, EnhancedLocationProvider locationProvider) async {
    // Dismiss any existing banners first
    InfoBannerService.dismiss();
    
    try {
      LocationSearchResult? targetLocation;
      
      if (locationProvider.mode == LocationMode.currentLocation) {
        final currentLocation = locationProvider.currentLocation;
        if (currentLocation != null) {
          targetLocation = LocationSearchResult(
            id: 'current_location',
            type: 'Current',
            name: 'Current Location',
            formattedAddress: currentLocation.address,
            locality: '',
            countryCode: '',
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
            confidence: 'high',
          );
        }
      } else {
        targetLocation = locationProvider.selectedLocation;
      }
      
      if (targetLocation == null) {
        InfoBannerService.show(
          context: context,
          message: 'Please enter a location',
          type: InfoBannerType.error,
        );
        return;
      }

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