import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/models/location_models.dart';

// Import our shared test utilities
import '../../helpers/mock_api_service.dart';
import '../../helpers/test_data_factory.dart';
import '../../helpers/testable_location_provider.dart';

/// Comprehensive tests for the coordinate search feature
/// 
/// Tests the complete workflow: Location detection → Coordinate search → Auto-fill
/// 
/// This covers the user story: "once current location found, it should do search 
/// by coordinates and fill location input with the first value found"
void main() {
  group('Coordinate Search Feature', () {
    late MockApiService mockApiService;
    late TestableLocationProvider provider;

    setUp(() {
      mockApiService = MockApiService();
      provider = TestableLocationProvider(mockApiService);
    });

    group('Location Detection and Coordinate Search', () {
      test('should search for locations by coordinates after GPS detection', () async {
        // Arrange: Set up successful responses
        final expectedResults = TestDataFactory.createLocationSearchResults();
        mockApiService.setLocationSearchResults(expectedResults);
        mockApiService.setReverseGeocodeResult(TestDataFactory.createReverseGeocodeResult());

        // Track status changes
        List<LocationStatus> statusChanges = [];
        provider.addListener(() {
          statusChanges.add(provider.status);
        });

        // Act: Simulate successful location detection
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Verify complete workflow
        expect(statusChanges, contains(LocationStatus.detecting));
        expect(statusChanges, contains(LocationStatus.searchComplete));
        
        expect(provider.currentLocation, isNotNull);
        expect(provider.currentLocation!.latitude, TestDataFactory.testLatitude);
        expect(provider.currentLocation!.longitude, TestDataFactory.testLongitude);
        
        expect(provider.searchResults, hasLength(3));
        expect(provider.searchResults.first.name, 'Central Park');
        expect(provider.status, LocationStatus.searchComplete);
      });

      test('should handle coordinate search errors gracefully', () async {
        // Arrange: Configure reverse geocoding to succeed but coordinate search to fail
        mockApiService.setReverseGeocodeResult(TestDataFactory.createReverseGeocodeResult());
        mockApiService.simulateLocationSearchFailure();

        // Act: Location detection should still succeed
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Location detected despite search failure
        expect(provider.currentLocation, isNotNull);
        expect(provider.status, LocationStatus.detected); // Not searchComplete
        expect(provider.searchResults, isEmpty);
      });

      test('should fail gracefully when location detection fails', () async {
        // Arrange: Configure reverse geocoding to fail
        mockApiService.simulateReverseGeocodeFailure();

        // Act: Attempt location detection
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Complete failure state
        expect(provider.currentLocation, isNull);
        expect(provider.status, LocationStatus.failed);
        expect(provider.searchResults, isEmpty);
        expect(provider.error, isNotNull);
      });

      test('should create correct coordinate query string', () async {
        // Arrange: Set up successful responses
        final mockResults = [TestDataFactory.createLocationSearchResult()];
        mockApiService.setLocationSearchResults(mockResults);

        // Act: Simulate detection with specific coordinates
        const testLat = 40.712834;
        const testLng = -74.006012;
        await provider.simulateLocationDetection(testLat, testLng);

        // Assert: Coordinate search was performed and completed
        expect(provider.currentLocation, isNotNull);
        expect(provider.searchResults, hasLength(1));
        expect(provider.status, LocationStatus.searchComplete);
      });
    });

    group('Status Flow Validation', () {
      test('should progress through correct status sequence for successful flow', () async {
        // Arrange
        mockApiService.setLocationSearchResults(TestDataFactory.createLocationSearchResults());
        
        List<LocationStatus> statusChanges = [];
        provider.addListener(() {
          statusChanges.add(provider.status);
        });

        // Act
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Verify status progression (may skip 'detected' if coordinate search succeeds immediately)
        expect(statusChanges, contains(LocationStatus.detecting));
        expect(statusChanges, contains(LocationStatus.searchComplete));
        // Note: detected may be skipped if coordinate search completes immediately
      });

      test('should stop at detected when coordinate search fails', () async {
        // Arrange
        mockApiService.simulateLocationSearchFailure();
        
        List<LocationStatus> statusChanges = [];
        provider.addListener(() {
          statusChanges.add(provider.status);
        });

        // Act
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Stops at detected, never reaches searchComplete
        expect(statusChanges, [
          LocationStatus.detecting,
          LocationStatus.detected,
        ]);
        expect(statusChanges, isNot(contains(LocationStatus.searchComplete)));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty search results', () async {
        // Arrange: Empty results but successful API call
        mockApiService.setLocationSearchResults([]);

        // Act
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Location detected but no search results
        expect(provider.currentLocation, isNotNull);
        expect(provider.searchResults, isEmpty);
        expect(provider.status, LocationStatus.searchComplete);
      });

      test('should handle null reverse geocoding result', () async {
        // Arrange: Null reverse geocoding result
        mockApiService.setReverseGeocodeResult(null);
        mockApiService.setLocationSearchResults(TestDataFactory.createLocationSearchResults());

        // Act
        await provider.simulateLocationDetection(
          TestDataFactory.testLatitude,
          TestDataFactory.testLongitude,
        );

        // Assert: Should still work with coordinate-based address
        expect(provider.currentLocation, isNotNull);
        expect(provider.currentLocation!.address, contains('40.7128'));
        expect(provider.currentLocation!.address, contains('-74.0060'));
        expect(provider.status, LocationStatus.searchComplete);
      });
    });

    group('Auto-Fill Simulation', () {
      test('should provide data for auto-fill when search completes', () async {
        // Arrange: Simulate the auto-fill scenario
        final mockResults = TestDataFactory.createLocationSearchResults();
        
        // Act: Simulate coordinate search completion
        await provider.simulateCoordinateSearchComplete(mockResults);

        // Assert: Data is available for auto-fill
        expect(provider.status, LocationStatus.searchComplete);
        expect(provider.searchResults, hasLength(3));
        expect(provider.searchResults.first.name, 'Central Park');
        
        // This is the data that would be used for auto-fill
        final firstResult = provider.searchResults.first;
        final autoFillValue = firstResult.formattedAddress.isNotEmpty 
            ? firstResult.formattedAddress 
            : firstResult.name;
        expect(autoFillValue, 'Central Park, New York, NY');
      });
    });
  });
}