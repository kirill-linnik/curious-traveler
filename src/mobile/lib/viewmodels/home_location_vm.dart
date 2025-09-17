import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location_models.dart';
import '../providers/enhanced_location_provider.dart';

/// ViewModel for managing location input state with race-free programmatic text updates
/// 
/// This class ensures:
/// - Single TextEditingController for the lifetime of the screen
/// - Safe programmatic text updates without triggering onChanged callbacks
/// - Proper coordination between manual typing and programmatic updates
/// - Clear composition range handling to prevent IME interference
/// - Separation of queryText (for search) and displayText (for field display)
class HomeLocationVm extends ChangeNotifier {
  final TextEditingController locationController = TextEditingController();
  
  // Flags to prevent feedback loops and race conditions
  bool _suppressOnChanged = false;

  // Split text state - CRITICAL for preventing provider overwrites
  String queryText = '';              // what user types for searching (drives API calls)
  String displayText = '';            // what the TextField shows (driven by controller)

  // Location state
  LocationSnapshot? currentLocationSnapshot;
  LocationSearchResult? anotherLocationSelection;
  LocationMode locationSource = LocationMode.currentLocation;
  
  // Search results for suggestions
  List<LocationSearchResult> searchResults = [];
  
  // Callback to close suggestions overlay
  VoidCallback? _closeSuggestionsCallback;

  HomeLocationVm() {
    // Controller created
  }

  @override
  void dispose() {
    locationController.dispose();
    super.dispose();
  }

  /// Set text programmatically without triggering onChanged callbacks
  /// This method ensures race-free updates by:
  /// 1. Setting a suppression flag
  /// 2. Clearing the composing range to avoid IME interference
  /// 3. Setting the text and cursor position
  /// 4. Updating displayText to match controller
  /// 5. Releasing suppression on the next frame
  void setTextProgrammatically(String text) {
    _suppressOnChanged = true;
    
    void _write() {
      locationController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }

    // 1) Immediate write
    _write();

    // 2) Microtask write (beats immediate onChanged/overlay)
    scheduleMicrotask(_write);

    // 3) Next frame write (beats rebuild & IME composition)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _write();
      _suppressOnChanged = false;
    });
    
    // Update displayText to match controller
    displayText = text;
  }
  
  /// For testing: clear suppression flag manually
  void clearSuppressionForTesting() {
    _suppressOnChanged = false;
  }

  /// Clear the location input field programmatically
  void clearText() {
    setTextProgrammatically('');
    queryText = '';
    displayText = '';
    anotherLocationSelection = null;
    notifyListeners();
  }
  
  /// Set the callback to close suggestions overlay
  void setCloseSuggestionsCallback(VoidCallback? callback) {
    _closeSuggestionsCallback = callback;
  }
  
  /// Close the suggestions overlay
  void closeSuggestions() {
    _closeSuggestionsCallback?.call();
  }
  
  /// Update search results
  void updateSearchResults(List<LocationSearchResult> results) {
    searchResults = results;
    notifyListeners();
  }

  /// Check if onChanged events should be suppressed
  bool get shouldSuppressOnChanged => _suppressOnChanged;

  /// Handle location mode changes with proper text updates
  void handleModeChanged(LocationMode mode) {
    final oldMode = locationSource;
    locationSource = mode;

    if (mode == LocationMode.currentLocation) {
      // When switching to Current location, ALWAYS override input with snapshot
      final snap = currentLocationSnapshot?.displayText ?? '';
      setTextProgrammatically(snap);   // ALWAYS override with snapshot
      displayText = snap;
      queryText = snap;
      anotherLocationSelection = null;
    } else if (mode == LocationMode.anotherLocation && oldMode == LocationMode.currentLocation) {
      // When switching from Current to Another location for the first time, clear the field
      setTextProgrammatically('');
      displayText = '';
      queryText = '';
    }
    
    notifyListeners();
  }

  /// Handle location suggestion selection in Another location mode
  void handleLocationSelected(LocationSearchResult result, [BuildContext? context]) {
    final display = result.formattedAddress.isNotEmpty 
        ? result.formattedAddress 
        : result.name;
        
    // Kill any pending searches and debounce
    // TODO: Add debounce cancellation when implemented
    
    // Set field deterministically (composition-safe with double-frame)
    setTextProgrammatically(display);
    
    // Update both query and display text to prevent provider overwrites
    queryText = display;
    displayText = display;
    anotherLocationSelection = result;
    
    // Close keyboard & overlay AFTER frame to allow tap gesture to complete
    if (context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).unfocus();
      });
    }
    
    notifyListeners();
  }

  /// Handle manual text changes (typing)
  /// Updates queryText for searching and displayText to match what's shown
  void handleTextChanged(String text) {
    if (_suppressOnChanged) {
      return;
    }
    
    if (locationSource != LocationMode.anotherLocation) {
      return;
    }
    
    // Update queryText for search (this drives API calls)
    queryText = text;
    // Do NOT set displayText here - let it be driven by controller
    
    // Clear any previous selection when user types manually
    anotherLocationSelection = null;
    
    notifyListeners();
  }

  /// Set current location snapshot from reverse geocoding
  void setCurrentLocationSnapshot(LocationSnapshot snapshot) {
    currentLocationSnapshot = snapshot;
    
    // If we're in current location mode and the field is empty, update it
    if (locationSource == LocationMode.currentLocation && locationController.text.isEmpty) {
      setTextProgrammatically(snapshot.displayText);
      displayText = snapshot.displayText;
      queryText = snapshot.displayText;
    }
    
    notifyListeners();
  }

  /// Get the currently selected location for itinerary generation
  LocationSearchResult? get selectedLocation {
    if (locationSource == LocationMode.currentLocation && currentLocationSnapshot != null) {
      // Convert current location snapshot to LocationSearchResult
      final snapshot = currentLocationSnapshot!;
      return LocationSearchResult(
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
    } else {
      return anotherLocationSelection;
    }
  }

  /// Check if we have a valid location selected
  bool get hasValidLocation => selectedLocation != null;

  /// Handle provider changes and update text if needed
  void handleProviderChange(EnhancedLocationProvider provider) {
    // Handle initial current location population
    if (provider.mode == LocationMode.currentLocation &&
        provider.status == LocationStatus.searchComplete &&
        provider.searchResults.isNotEmpty &&
        locationController.text.isEmpty) {
      
      final firstResult = provider.searchResults.first;
      final displayText = firstResult.formattedAddress.isNotEmpty 
          ? firstResult.formattedAddress 
          : firstResult.name;
      
      setTextProgrammatically(displayText);
      
      // Save current location as snapshot for later restoration
      final snapshot = LocationSnapshot.fromCurrentLocation(
        displayText: displayText,
        latitude: firstResult.latitude,
        longitude: firstResult.longitude,
        locality: firstResult.locality.isNotEmpty ? firstResult.locality : null,
      );
      setCurrentLocationSnapshot(snapshot);
      
      // Also select this location in the provider
      provider.selectLocation(firstResult);
    }
  }
}