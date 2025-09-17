import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/models/itinerary_models.dart';

/// Test data factory for creating common test objects
/// 
/// Provides pre-configured test data to avoid duplication and ensure consistency
/// across test files. All test data uses realistic but clearly fake values.
class TestDataFactory {
  
  // Location test data - NYC area for consistency
  static const double testLatitude = 40.7128;
  static const double testLongitude = -74.0060;
  static const String testAddress = "123 Test Street, Test City";
  static const String testCity = "Test City";
  static const String testCountryCode = "US";

  /// Creates a sample ReverseGeocodeResult for testing
  static ReverseGeocodeResult createReverseGeocodeResult({
    String? formattedAddress,
    String? locality,
    String? countryCode,
    double? latitude,
    double? longitude,
  }) {
    return ReverseGeocodeResult(
      formattedAddress: formattedAddress ?? testAddress,
      locality: locality ?? testCity,
      countryCode: countryCode ?? testCountryCode,
      latitude: latitude ?? testLatitude,
      longitude: longitude ?? testLongitude,
    );
  }

  /// Creates a sample LocationSearchResult for testing
  static LocationSearchResult createLocationSearchResult({
    String? id,
    String? type,
    String? name,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? locality,
    String? countryCode,
    String? confidence,
  }) {
    return LocationSearchResult(
      id: id ?? "test-location-1",
      type: type ?? "POI",
      name: name ?? "Test Location",
      latitude: latitude ?? testLatitude,
      longitude: longitude ?? testLongitude,
      formattedAddress: formattedAddress ?? testAddress,
      locality: locality ?? testCity,
      countryCode: countryCode ?? testCountryCode,
      confidence: confidence ?? "High",
    );
  }

  /// Creates multiple LocationSearchResults for testing search scenarios
  static List<LocationSearchResult> createLocationSearchResults() {
    return [
      createLocationSearchResult(
        id: "1",
        name: "Central Park",
        latitude: 40.7829,
        longitude: -73.9654,
        formattedAddress: "Central Park, New York, NY",
        locality: "New York",
      ),
      createLocationSearchResult(
        id: "2",
        name: "Times Square",
        latitude: 40.7580,
        longitude: -73.9855,
        formattedAddress: "Times Square, New York, NY",
        locality: "New York",
      ),
      createLocationSearchResult(
        id: "3",
        name: "Brooklyn Bridge",
        latitude: 40.7061,
        longitude: -73.9969,
        formattedAddress: "Brooklyn Bridge, New York, NY",
        locality: "New York",
      ),
    ];
  }

  /// Creates a Location object for testing
  static Location createLocation({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return Location(
      latitude: latitude ?? testLatitude,
      longitude: longitude ?? testLongitude,
      address: address ?? testAddress,
    );
  }
}