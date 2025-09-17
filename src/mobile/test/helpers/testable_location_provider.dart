import 'package:curious_traveler/providers/enhanced_location_provider.dart';
import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/models/itinerary_models.dart';
import 'package:curious_traveler/services/api_service.dart';

/// Testable version of EnhancedLocationProvider for unit testing
/// 
/// This class extends the main provider and allows us to:
/// - Bypass GPS/location services for testing
/// - Directly control the internal state
/// - Simulate location detection and coordinate search scenarios
/// 
/// Use this instead of the main provider in unit tests to avoid
/// dependencies on actual device location services.
class TestableLocationProvider extends EnhancedLocationProvider {
  final ApiService _testApiService;
  
  TestableLocationProvider(this._testApiService) : super(_testApiService);

  /// Simulate location detection without GPS
  /// 
  /// This method replicates the logic of detectCurrentLocation() but bypasses
  /// actual GPS/location services, making it perfect for unit testing.
  Future<void> simulateLocationDetection(double latitude, double longitude) async {
    _status = LocationStatus.detecting;
    _error = null;
    notifyListeners();

    try {
      // Simulate reverse geocoding
      final reverseResult = await _testApiService.reverseGeocode(latitude, longitude);
      
      if (reverseResult != null) {
        _currentLocation = Location(
          latitude: latitude,
          longitude: longitude,
          address: reverseResult.formattedAddress,
        );
      } else {
        _currentLocation = Location(
          latitude: latitude,
          longitude: longitude,
          address: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
        );
      }

      _status = LocationStatus.detected;
      _error = null;

      // Automatically search for nearby locations using coordinates
      await _searchLocationsByCoordinates(latitude, longitude);

    } catch (e) {
      _error = e.toString();
      _currentLocation = null;
      _status = LocationStatus.failed;
    }

    notifyListeners();
  }

  /// Simulate coordinate search completion
  /// 
  /// Useful for testing UI responses to coordinate search results
  /// without going through the full location detection flow.
  Future<void> simulateCoordinateSearchComplete(List<LocationSearchResult> results) async {
    _status = LocationStatus.searchComplete;
    _searchResults = results;
    notifyListeners();
  }

  /// Internal method to perform coordinate search
  Future<void> _searchLocationsByCoordinates(double latitude, double longitude) async {
    try {
      _searchResults = await _testApiService.searchLocations(
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
        language: 'en',
        latitude: latitude,
        longitude: longitude,
        limit: 10,
      );
      
      _status = LocationStatus.searchComplete;
    } catch (e) {
      // If coordinate search fails, keep the status as detected
      // The location detection succeeded even if coordinate search failed
      _status = LocationStatus.detected;
    }
  }

  // Internal state access for testing
  LocationStatus _status = LocationStatus.unknown;
  Location? _currentLocation;
  List<LocationSearchResult> _searchResults = [];
  String? _error;

  // Override getters for controlled access
  @override
  LocationStatus get status => _status;

  @override
  Location? get currentLocation => _currentLocation;

  @override
  List<LocationSearchResult> get searchResults => _searchResults;

  @override
  String? get error => _error;

  // Setters for direct state manipulation in tests
  set status(LocationStatus value) {
    _status = value;
  }

  set currentLocation(Location? value) {
    _currentLocation = value;
  }

  set searchResults(List<LocationSearchResult> value) {
    _searchResults = value;
  }

  set error(String? value) {
    _error = value;
  }
}