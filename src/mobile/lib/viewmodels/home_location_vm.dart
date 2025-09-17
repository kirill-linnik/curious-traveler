import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location_models.dart';
import '../providers/enhanced_location_provider.dart';
import '../services/api_service.dart';
import 'journey_endpoint_state.dart';

/// ViewModel for managing dual-block location input state
/// 
/// This class manages:
/// - Two independent journey endpoints (start and end)
/// - Shared current location snapshot
/// - API calls for location search
/// - Coordination between the blocks
class HomeLocationVm extends ChangeNotifier {
  LocationSnapshot? currentLocationSnapshot;
  bool hasResolvedCurrentOnce = false;

  final start = JourneyEndPointState('start');
  final end = JourneyEndPointState('end');

  // API service for search calls
  ApiService? _apiService;

  HomeLocationVm() {
    // Initialize endpoints with listeners
    start.addListener(notifyListeners);
    end.addListener(notifyListeners);
  }

  void setApiService(ApiService service) {
    _apiService = service;
  }

  @override
  void dispose() {
    start.removeListener(notifyListeners);
    end.removeListener(notifyListeners);
    start.dispose();
    end.dispose();
    super.dispose();
  }

  /// Set current location snapshot and prefill both blocks
  void setCurrentSnapshot(LocationSnapshot snap) {
    if (hasResolvedCurrentOnce) return;
    
    currentLocationSnapshot = snap;

    // Prefill BOTH blocks - set mode FIRST, then text
    for (final ep in [start, end]) {
      ep.mode = LocationMode.currentLocation;          // FIRST: explicit mode
      ep.setTextProgrammatically(snap.displayText);    // THEN: composition-safe text
      ep.displayText = snap.displayText;
      ep.queryText = snap.displayText;
      ep.selection = null;                             // clear any existing selection
      ep.suggestions.clear();                          // clear suggestions
      ep.showSuggestions = false;                     // hide suggestions
    }

    hasResolvedCurrentOnce = true;
    notifyListeners();
  }

  /// Search locations using the API service
  Future<List<LocationSelection>> searchLocations(String query) async {
    if (_apiService == null) return [];
    
    try {
      // Use current location snapshot for bias if available
      final bias = currentLocationSnapshot?.position;
      final results = await _apiService!.searchLocations(
        query,
        latitude: bias?.lat,
        longitude: bias?.lon,
      );
      return results.map((result) => LocationSelection.fromSearchResult(result)).toList();
    } catch (e) {
      return [];
    }
  }

  // Convenience getters for planner
  bool get hasStartPoint => start.mode == LocationMode.currentLocation
                          ? currentLocationSnapshot != null
                          : start.selection != null;

  bool get hasEndPoint => end.mode == LocationMode.currentLocation
                        ? currentLocationSnapshot != null
                        : end.selection != null;

  ({double lat, double lon})? get startCoords =>
    start.mode == LocationMode.currentLocation
      ? currentLocationSnapshot?.position
      : start.selection?.position;

  ({double lat, double lon})? get endCoords =>
    end.mode == LocationMode.currentLocation
      ? currentLocationSnapshot?.position   // reuse SAME snapshot
      : end.selection?.position;

  /// Legacy compatibility method for provider integration
  void handleProviderChange(EnhancedLocationProvider provider) {
    // Handle initial current location population
    // Check for BOTH detected AND searchComplete status
    if (provider.mode == LocationMode.currentLocation &&
        (provider.status == LocationStatus.detected || provider.status == LocationStatus.searchComplete) &&
        provider.currentLocation != null &&
        !hasResolvedCurrentOnce) {
      
      final currentLocation = provider.currentLocation!;
      final snapshot = LocationSnapshot.fromCurrentLocation(
        displayText: currentLocation.address,
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        locality: null,
      );
      setCurrentSnapshot(snapshot);
    }
  }

  /// Legacy compatibility - unused in new implementation
  void updateSearchResults(List<LocationSearchResult> results) {
    // No longer needed - each endpoint manages its own search
  }

  /// Legacy compatibility - unused in new implementation  
  String get queryText => '';
  String get displayText => '';
  LocationMode get locationSource => LocationMode.currentLocation;
  bool get shouldSuppressOnChanged => false;
  TextEditingController get locationController => TextEditingController(); // Dummy
  
  /// Legacy compatibility methods - unused in new implementation
  void handleModeChanged(LocationMode mode) {}
  void handleLocationSelected(LocationSearchResult result, [BuildContext? context]) {}
  void handleTextChanged(String text) {}
  void setCurrentLocationSnapshot(LocationSnapshot snapshot) {}
  LocationSearchResult? get selectedLocation => null;
  bool get hasValidLocation => hasStartPoint && hasEndPoint;
  void setCloseSuggestionsCallback(VoidCallback? callback) {}
  void closeSuggestions() {}
  void clearText() {}
  void clearSuppressionForTesting() {}
  void setTextProgrammatically(String text) {}
}