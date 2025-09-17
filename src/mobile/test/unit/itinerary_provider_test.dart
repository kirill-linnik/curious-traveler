import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:curious_traveler/providers/itinerary_provider.dart';
import 'package:curious_traveler/models/itinerary_models.dart';
import 'package:curious_traveler/services/api_service.dart';
import 'package:curious_traveler/providers/enhanced_location_provider.dart';

class MockApiService extends Mock implements ApiService {}
class MockEnhancedLocationProvider extends Mock implements EnhancedLocationProvider {}

// Fake implementations for mocktail
class FakeItineraryRequest extends Fake implements ItineraryRequest {}
class FakeItineraryUpdateRequest extends Fake implements ItineraryUpdateRequest {}

void main() {
  group('ItineraryProvider Tests', () {
    late ItineraryProvider itineraryProvider;
    late MockApiService mockApiService;
    late MockEnhancedLocationProvider mockLocationProvider;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(FakeItineraryRequest());
      registerFallbackValue(FakeItineraryUpdateRequest());
    });

    setUp(() {
      mockApiService = MockApiService();
      mockLocationProvider = MockEnhancedLocationProvider();
      itineraryProvider = ItineraryProvider(mockApiService, mockLocationProvider);
    });

    test('initial state should be correct', () {
      expect(itineraryProvider.currentItinerary, isNull);
      expect(itineraryProvider.isLoading, isFalse);
      expect(itineraryProvider.error, isNull);
    });

    group('generateItinerary', () {
      const testLocation = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: 'San Francisco, CA',
      );

      final testItinerary = Itinerary(
        itineraryId: 'test_123',
        locations: [
          const ItineraryLocation(
            id: 'loc_1',
            name: 'Golden Gate Bridge',
            description: 'Famous bridge',
            location: testLocation,
            duration: 60,
            category: 'landmark',
            travelTime: 15,
            travelDistance: 2500.0,
            order: 1,
          ),
        ],
        totalDuration: 75,
        commuteStyle: 'walking',
      );

      test('should generate itinerary successfully', () async {
        // Arrange
        when(() => mockLocationProvider.currentLocation).thenReturn(testLocation);
        when(() => mockApiService.generateItinerary(any())).thenAnswer((_) async => testItinerary);

        // Act
        await itineraryProvider.generateItinerary(
          city: 'San Francisco',
          commuteStyle: CommuteStyle.walking,
          duration: 4,
          interests: ['landmarks', 'nature'],
        );

        // Assert
        expect(itineraryProvider.currentItinerary, equals(testItinerary));
        expect(itineraryProvider.isLoading, isFalse);
        expect(itineraryProvider.error, isNull);
        
        verify(() => mockApiService.generateItinerary(any())).called(1);
      });

      test('should set loading state during generation', () async {
        // Arrange
        when(() => mockLocationProvider.currentLocation).thenReturn(testLocation);
        when(() => mockApiService.generateItinerary(any())).thenAnswer((_) async => testItinerary);

        bool wasLoadingDuringCall = false;

        // Act
        itineraryProvider.addListener(() {
          if (itineraryProvider.isLoading) {
            wasLoadingDuringCall = true;
          }
        });

        await itineraryProvider.generateItinerary(
          city: 'San Francisco',
          commuteStyle: CommuteStyle.walking,
          duration: 4,
          interests: ['landmarks'],
        );

        // Assert
        expect(wasLoadingDuringCall, isTrue);
        expect(itineraryProvider.isLoading, isFalse);
      });

      test('should handle generation errors', () async {
        // Arrange
        when(() => mockLocationProvider.currentLocation).thenReturn(testLocation);
        when(() => mockApiService.generateItinerary(any())).thenThrow(Exception('Network error'));

        // Act
        await itineraryProvider.generateItinerary(
          city: 'San Francisco',
          commuteStyle: CommuteStyle.walking,
          duration: 4,
          interests: ['landmarks'],
        );

        // Assert
        expect(itineraryProvider.currentItinerary, isNull);
        expect(itineraryProvider.isLoading, isFalse);
        expect(itineraryProvider.error, contains('Network error'));
      });
    });

    group('updateItinerary', () {
      const testLocation = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: 'San Francisco, CA',
      );

      final testItinerary = Itinerary(
        itineraryId: 'test_123',
        locations: [
          const ItineraryLocation(
            id: 'loc_1',
            name: 'Golden Gate Bridge',
            description: 'Famous bridge',
            location: testLocation,
            duration: 60,
            category: 'landmark',
            travelTime: 15,
            travelDistance: 2500.0,
            order: 1,
          ),
        ],
        totalDuration: 75,
        commuteStyle: 'walking',
      );

      test('should update itinerary successfully', () async {
        // Arrange
        itineraryProvider.debugSetItinerary(testItinerary); // Simulate existing itinerary
        when(() => mockLocationProvider.currentLocation).thenReturn(testLocation);
        when(() => mockApiService.updateItinerary(any())).thenAnswer((_) async => testItinerary);

        // Act
        await itineraryProvider.updateItinerary(
          locationId: 'loc_1',
          feedback: FeedbackType.like,
        );

        // Assert
        expect(itineraryProvider.currentItinerary, equals(testItinerary));
        expect(itineraryProvider.isLoading, isFalse);
        expect(itineraryProvider.error, isNull);
        
        verify(() => mockApiService.updateItinerary(any())).called(1);
      });

      test('should not update when no current itinerary exists', () async {
        // Act
        await itineraryProvider.updateItinerary(
          locationId: 'loc_1',
          feedback: FeedbackType.like,
        );

        // Assert
        verifyNever(() => mockApiService.updateItinerary(any()));
      });

      test('should handle update errors', () async {
        // Arrange
        itineraryProvider.debugSetItinerary(testItinerary);
        when(() => mockLocationProvider.currentLocation).thenReturn(testLocation);
        when(() => mockApiService.updateItinerary(any())).thenThrow(Exception('Server error'));

        // Act
        await itineraryProvider.updateItinerary(
          locationId: 'loc_1',
          feedback: FeedbackType.like,
        );

        // Assert
        expect(itineraryProvider.isLoading, isFalse);
        expect(itineraryProvider.error, contains('Server error'));
      });
    });

    group('getLocationNarration', () {
      test('should get narration successfully', () async {
        // Arrange
        const expectedNarration = 'Welcome to the Golden Gate Bridge...';
        when(() => mockApiService.getLocationNarration(any(), language: any(named: 'language')))
            .thenAnswer((_) async => expectedNarration);

        // Act
        final result = await itineraryProvider.getLocationNarration('loc_1');

        // Assert
        expect(result, expectedNarration);
        verify(() => mockApiService.getLocationNarration('loc_1', language: 'en-US')).called(1);
      });

      test('should handle narration errors gracefully', () async {
        // Arrange
        when(() => mockApiService.getLocationNarration(any(), language: any(named: 'language')))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await itineraryProvider.getLocationNarration('loc_1');

        // Assert
        expect(result, 'Unable to load narration for this location.');
      });
    });

    group('utility methods', () {
      test('should clear itinerary', () {
        // Arrange
        final testItinerary = Itinerary(
          itineraryId: 'test_123',
          locations: [],
          totalDuration: 0,
          commuteStyle: 'walking',
        );
        itineraryProvider.debugSetItinerary(testItinerary);

        // Act
        itineraryProvider.clearItinerary();

        // Assert
        expect(itineraryProvider.currentItinerary, isNull);
        expect(itineraryProvider.error, isNull);
      });

      test('should clear error', () {
        // Arrange
        itineraryProvider.debugSetError('Test error');

        // Act
        itineraryProvider.clearError();

        // Assert
        expect(itineraryProvider.error, isNull);
      });

      test('should get location by id', () {
        // Arrange
        const testLocation = Location(
          latitude: 37.7749,
          longitude: -122.4194,
          address: 'San Francisco, CA',
        );
        
        const itineraryLocation = ItineraryLocation(
          id: 'loc_1',
          name: 'Golden Gate Bridge',
          description: 'Famous bridge',
          location: testLocation,
          duration: 60,
          category: 'landmark',
          travelTime: 15,
          travelDistance: 2500.0,
          order: 1,
        );

        final testItinerary = Itinerary(
          itineraryId: 'test_123',
          locations: [itineraryLocation],
          totalDuration: 75,
          commuteStyle: 'walking',
        );

        itineraryProvider.debugSetItinerary(testItinerary);

        // Act
        final result = itineraryProvider.getLocationById('loc_1');

        // Assert
        expect(result, equals(itineraryLocation));
      });

      test('should return null for non-existent location id', () {
        // Arrange
        final testItinerary = Itinerary(
          itineraryId: 'test_123',
          locations: [],
          totalDuration: 0,
          commuteStyle: 'walking',
        );
        itineraryProvider.debugSetItinerary(testItinerary);

        // Act
        final result = itineraryProvider.getLocationById('non_existent');

        // Assert
        expect(result, isNull);
      });
    });
  });
}