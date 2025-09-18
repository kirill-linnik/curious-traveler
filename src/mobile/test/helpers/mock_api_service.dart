import 'package:curious_traveler/services/api_service.dart';
import 'package:curious_traveler/models/location_models.dart';
import 'package:curious_traveler/models/itinerary_models.dart';
import 'dart:typed_data';

/// Shared MockApiService for testing
/// 
/// Provides configurable responses for testing different scenarios:
/// - Location search with custom results
/// - Reverse geocoding with configurable success/failure
/// - Error simulation for network/service failures
class MockApiService implements ApiService {
  // Configuration flags for controlling mock behavior
  bool shouldFailReverseGeocode = false;
  bool shouldFailLocationSearch = false;
  
  // Mock data for responses
  List<LocationSearchResult> mockLocationResults = [];
  ReverseGeocodeResult? mockReverseGeocodeResult;

  // Default constructor with sensible defaults
  MockApiService() {
    mockReverseGeocodeResult = const ReverseGeocodeResult(
      formattedAddress: "123 Test Street, Test City",
      locality: "Test City",
      countryCode: "US",
      latitude: 40.7128,
      longitude: -74.0060,
    );
  }

  @override
  Future<ReverseGeocodeResult?> reverseGeocode(double latitude, double longitude, {String language = 'en'}) async {
    if (shouldFailReverseGeocode) {
      throw Exception('Location service error');
    }
    return mockReverseGeocodeResult;
  }

  @override
  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    String language = 'en',
    double? latitude,
    double? longitude,
    int limit = 10,
  }) async {
    if (shouldFailLocationSearch) {
      throw Exception('Network error');
    }
    return mockLocationResults;
  }

  // Convenience methods for setting up common test scenarios
  
  /// Configure mock to return successful location search results
  void setLocationSearchResults(List<LocationSearchResult> results) {
    mockLocationResults = results;
    shouldFailLocationSearch = false;
  }

  /// Configure mock to return specific reverse geocoding result
  void setReverseGeocodeResult(ReverseGeocodeResult? result) {
    mockReverseGeocodeResult = result;
    shouldFailReverseGeocode = false;
  }

  /// Configure mock to simulate location search failure
  void simulateLocationSearchFailure() {
    shouldFailLocationSearch = true;
  }

  /// Configure mock to simulate reverse geocoding failure
  void simulateReverseGeocodeFailure() {
    shouldFailReverseGeocode = true;
  }

  /// Reset all configurations to defaults
  void reset() {
    shouldFailReverseGeocode = false;
    shouldFailLocationSearch = false;
    mockLocationResults.clear();
    mockReverseGeocodeResult = const ReverseGeocodeResult(
      formattedAddress: "123 Test Street, Test City",
      locality: "Test City",
      countryCode: "US",
      latitude: 40.7128,
      longitude: -74.0060,
    );
  }

  // Implement other required methods with proper signatures
  @override
  Future<Itinerary> generateItinerary(ItineraryRequest request) async {
    throw ApiException('Itinerary generation is not yet available', 501);
  }

  @override
  Future<Itinerary> updateItinerary(ItineraryUpdateRequest request) async {
    throw ApiException('Itinerary update is not yet available', 501);
  }

  @override
  Future<String> getLocationNarration(String locationId, {String language = 'en-US'}) async {
    throw ApiException('Location narration is not yet available', 501);
  }

  @override
  Future<Uint8List> generateAudio(String text, {String language = 'en-US'}) async {
    throw ApiException('Audio generation is not yet available', 501);
  }

  @override
  Future<String> getSupportedVoice({String language = 'en-US'}) async {
    throw ApiException('Voice support check is not yet available', 501);
  }

  @override
  Future<ItineraryJobResponse> createItineraryJob(ItineraryJobRequest request) async {
    throw ApiException('Itinerary job creation is not yet available', 501);
  }

  @override
  Future<ItineraryJobResponse> getItineraryJob(String jobId) async {
    throw ApiException('Itinerary job retrieval is not yet available', 501);
  }

  @override
  void dispose() {}
}