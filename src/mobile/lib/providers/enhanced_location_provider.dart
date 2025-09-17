import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/itinerary_models.dart';
import '../models/location_models.dart';
import '../services/api_service.dart';

class EnhancedLocationProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  LocationMode _mode = LocationMode.currentLocation;
  LocationStatus _status = LocationStatus.unknown;
  Location? _currentLocation;
  LocationSearchResult? _selectedLocation;
  List<LocationSearchResult> _searchResults = [];
  String? _error;
  Timer? _searchDebounce;
  
  // Immutable snapshot of current location detection result
  // This is set once during initial location detection and never changes
  LocationSnapshot? _currentLocationSnapshot;

  // Getters
  LocationMode get mode => _mode;
  LocationStatus get status => _status;
  Location? get currentLocation => _currentLocation;
  LocationSearchResult? get selectedLocation => _selectedLocation;
  List<LocationSearchResult> get searchResults => _searchResults;
  String? get error => _error;
  bool get isLoading => _status == LocationStatus.detecting || _status == LocationStatus.searching;
  LocationSnapshot? get currentLocationSnapshot => _currentLocationSnapshot;

  EnhancedLocationProvider(this._apiService);

  void setMode(LocationMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      _error = null;
      _searchResults.clear();
      _selectedLocation = null;
      
      // Clear search status when switching modes
      if (_status == LocationStatus.searching || _status == LocationStatus.searchComplete || _status == LocationStatus.searchFailed) {
        _status = LocationStatus.unknown;
      }
      
      notifyListeners();
    }
  }

  Future<void> detectCurrentLocation() async {
    // Only detect current location once per provider instance
    if (_currentLocationSnapshot != null) {
      return;
    }

    _status = LocationStatus.detecting;
    _error = null;
    notifyListeners();

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Reverse geocode the position
      final reverseResult = await _reverseGeocode(position.latitude, position.longitude);
      
      String displayText;
      String? locality;
      
      if (reverseResult != null) {
        _currentLocation = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          address: reverseResult.formattedAddress,
        );
        displayText = reverseResult.formattedAddress;
        locality = reverseResult.locality.isNotEmpty ? reverseResult.locality : null;
      } else {
        final coordinateText = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _currentLocation = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          address: coordinateText,
        );
        displayText = coordinateText;
        locality = null;
      }

      // Create immutable snapshot for the lifetime of this provider instance
      _currentLocationSnapshot = LocationSnapshot.fromCurrentLocation(
        displayText: displayText,
        locality: locality,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _status = LocationStatus.detected;
      _error = null;

      // Automatically search for nearby locations using coordinates
      await _searchLocationsByCoordinates(position.latitude, position.longitude);

    } catch (e) {
      _error = e.toString();
      _currentLocation = null;
      _currentLocationSnapshot = null;  // Ensure snapshot is null on failure
      _status = LocationStatus.failed;
    }

    notifyListeners();
  }

  Future<void> _searchLocationsByCoordinates(double latitude, double longitude) async {
    try {
      // Search for locations near the current coordinates
      _searchResults = await _apiService.searchLocations(
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
        language: 'en', // TODO: Get from locale provider
        latitude: latitude,
        longitude: longitude,
        limit: 10,
      );
      
      // If we found results, update status to searchComplete
      if (_searchResults.isNotEmpty) {
        _status = LocationStatus.searchComplete;
      }
    } catch (e) {
      debugPrint('Coordinate search error: $e');
      // Don't fail the entire location detection if coordinate search fails
      // Keep the detected status
    }
  }

  Future<ReverseGeocodeResult?> _reverseGeocode(double latitude, double longitude) async {
    try {
      return await _apiService.reverseGeocode(latitude, longitude, language: 'en'); // TODO: Get from locale provider
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      return null;
    }
  }

  void searchLocations(String query) {
    if (query.trim().length < 2) {
      _searchResults.clear();
      _status = LocationStatus.unknown;
      notifyListeners();
      return;
    }

    // Debounce the search
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    _status = LocationStatus.searching;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _apiService.searchLocations(
        query,
        language: 'en', // TODO: Get from locale provider
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
        limit: 10,
      );
      
      _status = LocationStatus.searchComplete;
      _error = null;
    } catch (e) {
      _searchResults.clear();
      _error = 'Search error: $e';
      _status = LocationStatus.searchFailed;
    }

    notifyListeners();
  }

  void selectLocation(LocationSearchResult location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults.clear();
    _searchDebounce?.cancel();
    if (_status == LocationStatus.searching || _status == LocationStatus.searchComplete || _status == LocationStatus.searchFailed) {
      _status = LocationStatus.unknown;
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get the effective location for itinerary generation
  Location? getEffectiveLocation() {
    if (_mode == LocationMode.currentLocation) {
      return _currentLocation;
    } else if (_selectedLocation != null) {
      return Location(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _selectedLocation!.formattedAddress,
      );
    }
    return null;
  }

  // Get the effective starting point for UI display
  LocationSnapshot? getEffectiveStartingPoint() {
    if (_mode == LocationMode.currentLocation) {
      return _currentLocationSnapshot;
    } else if (_selectedLocation != null) {
      return LocationSnapshot.fromSearchResult(result: _selectedLocation!);
    }
    return null;
  }

  // Legacy methods for backward compatibility
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      _error = 'Failed to request location permission: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentLocation() async {
    setMode(LocationMode.currentLocation);
    await detectCurrentLocation();
  }

  Future<double> getDistanceBetween(Location from, Location to) async {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}