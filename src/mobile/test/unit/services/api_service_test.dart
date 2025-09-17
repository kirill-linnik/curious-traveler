import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/services/api_service.dart';
import 'package:curious_traveler/models/itinerary_models.dart';

void main() {
  group('ApiService Tests', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService();
    });

    tearDown(() {
      apiService.dispose();
    });

    group('Basic API Structure', () {
      test('should create ApiService instance', () {
        expect(apiService, isNotNull);
        expect(apiService, isA<ApiService>());
      });

      test('should have dispose method', () {
        expect(() => apiService.dispose(), returnsNormally);
      });
    });

    group('Model Validation', () {
      test('should create valid Location objects', () {
        final location = Location(
          latitude: 48.8566,
          longitude: 2.3522,
          address: 'Paris, France',
        );

        expect(location.latitude, 48.8566);
        expect(location.longitude, 2.3522);
        expect(location.address, 'Paris, France');
      });

      test('should create valid ItineraryLocation objects', () {
        final location = Location(
          latitude: 48.8606,
          longitude: 2.3376,
          address: 'Louvre Museum, Paris',
        );

        final itineraryLocation = ItineraryLocation(
          id: 'loc_1',
          name: 'Louvre Museum',
          description: 'World famous art museum',
          location: location,
          duration: 90,
          category: 'museum',
          travelTime: 15,
          travelDistance: 0.5,
          order: 0,
        );

        expect(itineraryLocation.id, 'loc_1');
        expect(itineraryLocation.name, 'Louvre Museum');
        expect(itineraryLocation.duration, 90);
        expect(itineraryLocation.order, 0);
      });

      test('should create valid Itinerary objects', () {
        final location = Location(
          latitude: 48.8606,
          longitude: 2.3376,
          address: 'Louvre Museum, Paris',
        );

        final itineraryLocation = ItineraryLocation(
          id: 'loc_1',
          name: 'Louvre Museum',
          description: 'World famous art museum',
          location: location,
          duration: 90,
          category: 'museum',
          travelTime: 15,
          travelDistance: 0.5,
          order: 0,
        );

        final itinerary = Itinerary(
          itineraryId: 'itinerary_123',
          locations: [itineraryLocation],
          totalDuration: 105, // 90 + 15 travel time
          commuteStyle: 'walking',
        );

        expect(itinerary.itineraryId, 'itinerary_123');
        expect(itinerary.locations.length, 1);
        expect(itinerary.totalDuration, 105);
        expect(itinerary.commuteStyle, 'walking');
      });

      test('should create valid ItineraryRequest objects', () {
        final startLocation = Location(
          latitude: 48.8566,
          longitude: 2.3522,
          address: 'Paris Center',
        );

        final request = ItineraryRequest(
          city: 'Paris',
          commuteStyle: 'walking',
          duration: 180,
          interests: ['museum', 'historical'],
          language: 'en-US',
          startLocation: startLocation,
        );

        expect(request.city, 'Paris');
        expect(request.commuteStyle, 'walking');
        expect(request.duration, 180);
        expect(request.interests, contains('museum'));
        expect(request.language, 'en-US');
        expect(request.startLocation, isNotNull);
      });

      test('should create valid ItineraryUpdateRequest objects', () {
        final currentLocation = Location(
          latitude: 48.8566,
          longitude: 2.3522,
          address: 'Current Position',
        );

        final updateRequest = ItineraryUpdateRequest(
          itineraryId: 'itinerary_123',
          locationId: 'loc_1',
          feedback: 'Great place, loved it!',
          currentLocation: currentLocation,
        );

        expect(updateRequest.itineraryId, 'itinerary_123');
        expect(updateRequest.locationId, 'loc_1');
        expect(updateRequest.feedback, 'Great place, loved it!');
        expect(updateRequest.currentLocation, isNotNull);
      });
    });

    group('Enum Validation', () {
      test('should have valid CommuteStyle enum values', () {
        expect(CommuteStyle.walking.value, 'walking');
        expect(CommuteStyle.transit.value, 'transit');
        expect(CommuteStyle.driving.value, 'driving');

        expect(CommuteStyle.walking.displayName, 'Walking');
        expect(CommuteStyle.transit.displayName, 'Public Transit');
        expect(CommuteStyle.driving.displayName, 'Driving');
      });

      test('should have valid FeedbackType enum values', () {
        expect(FeedbackType.like.value, 'like');
        expect(FeedbackType.dislike.value, 'dislike');
        expect(FeedbackType.moreTime.value, 'more_time');
        expect(FeedbackType.lessTime.value, 'less_time');

        expect(FeedbackType.like.displayName, 'Like');
        expect(FeedbackType.dislike.displayName, 'Dislike');
        expect(FeedbackType.moreTime.displayName, 'More Time');
        expect(FeedbackType.lessTime.displayName, 'Less Time');
      });
    });

    group('JSON Serialization', () {
      test('should serialize and deserialize Location', () {
        final original = Location(
          latitude: 48.8566,
          longitude: 2.3522,
          address: 'Paris, France',
        );

        final json = original.toJson();
        final deserialized = Location.fromJson(json);

        expect(deserialized.latitude, original.latitude);
        expect(deserialized.longitude, original.longitude);
        expect(deserialized.address, original.address);
      });

      test('should serialize and deserialize ItineraryRequest', () {
        final startLocation = Location(
          latitude: 48.8566,
          longitude: 2.3522,
          address: 'Paris Center',
        );

        final original = ItineraryRequest(
          city: 'Paris',
          commuteStyle: 'walking',
          duration: 180,
          interests: ['museum', 'historical'],
          language: 'en-US',
          startLocation: startLocation,
        );

        final json = original.toJson();
        final deserialized = ItineraryRequest.fromJson(json);

        expect(deserialized.city, original.city);
        expect(deserialized.commuteStyle, original.commuteStyle);
        expect(deserialized.duration, original.duration);
        expect(deserialized.interests, original.interests);
        expect(deserialized.language, original.language);
        expect(deserialized.startLocation?.latitude, original.startLocation?.latitude);
      });

      test('should handle null startLocation in ItineraryRequest', () {
        final original = ItineraryRequest(
          city: 'Paris',
          commuteStyle: 'walking',
          duration: 180,
          interests: ['museum'],
          language: 'en-US',
          startLocation: null,
        );

        final json = original.toJson();
        final deserialized = ItineraryRequest.fromJson(json);

        expect(deserialized.startLocation, isNull);
        expect(deserialized.city, original.city);
      });
    });

    group('ApiException', () {
      test('should create exception with message and status code', () {
        final exception = ApiException('Network error', 500);
        
        expect(exception.message, 'Network error');
        expect(exception.statusCode, 500);
        expect(exception.toString(), 'ApiException: Network error (Status: 500)');
      });

      test('should handle different HTTP status codes', () {
        final testCases = {
          400: 'Bad Request',
          401: 'Unauthorized',
          403: 'Forbidden',
          404: 'Not Found',
          429: 'Too Many Requests',
          500: 'Internal Server Error',
          502: 'Bad Gateway',
          503: 'Service Unavailable',
        };

        testCases.forEach((code, message) {
          final exception = ApiException(message, code);
          expect(exception.statusCode, code);
          expect(exception.message, message);
          expect(exception.toString(), contains(code.toString()));
        });
      });
    });

    group('Data Validation', () {
      test('should validate coordinate ranges', () {
        // Valid coordinates
        expect(() => Location(latitude: 0, longitude: 0, address: 'Equator'), returnsNormally);
        expect(() => Location(latitude: 90, longitude: 180, address: 'North Pole'), returnsNormally);
        expect(() => Location(latitude: -90, longitude: -180, address: 'South Pole'), returnsNormally);
        
        // Paris coordinates
        final paris = Location(latitude: 48.8566, longitude: 2.3522, address: 'Paris');
        expect(paris.latitude >= -90 && paris.latitude <= 90, true);
        expect(paris.longitude >= -180 && paris.longitude <= 180, true);
      });

      test('should validate duration values', () {
        final validDurations = [30, 60, 90, 120, 180, 240, 300, 360];
        
        for (final duration in validDurations) {
          final request = ItineraryRequest(
            city: 'Paris',
            commuteStyle: 'walking',
            duration: duration,
            interests: ['museum'],
          );
          
          expect(request.duration, duration);
          expect(request.duration > 0, true);
        }
      });

      test('should validate interest categories', () {
        const validInterests = [
          'museum',
          'historical',
          'nature',
          'food',
          'shopping',
          'entertainment',
          'cultural',
          'sports',
          'architecture',
          'art',
          'nightlife',
          'religious',
          'parks',
          'landmarks'
        ];

        for (final interest in validInterests) {
          final request = ItineraryRequest(
            city: 'Paris',
            commuteStyle: 'walking',
            duration: 180,
            interests: [interest],
          );
          
          expect(request.interests, contains(interest));
          expect(interest.isNotEmpty, true);
          expect(interest.toLowerCase(), interest);
        }
      });

      test('should validate commute styles', () {
        for (final style in CommuteStyle.values) {
          final request = ItineraryRequest(
            city: 'Paris',
            commuteStyle: style.value,
            duration: 180,
            interests: ['museum'],
          );
          
          expect(request.commuteStyle, style.value);
          expect(style.value.isNotEmpty, true);
        }
      });

      test('should validate language codes', () {
        const supportedLanguages = [
          'en-US',
          'fr-FR',
          'de-DE',
          'es-ES',
          'it-IT',
          'pt-PT',
          'nl-NL',
          'ru-RU',
          'ja-JP',
          'ko-KR',
          'zh-CN'
        ];

        for (final language in supportedLanguages) {
          final request = ItineraryRequest(
            city: 'Paris',
            commuteStyle: 'walking',
            duration: 180,
            interests: ['museum'],
            language: language,
          );
          
          expect(request.language, language);
          expect(language.length, 5);
          expect(language.contains('-'), true);
        }
      });
    });

    group('Edge Cases', () {
      test('should handle empty interests list', () {
        final request = ItineraryRequest(
          city: 'Paris',
          commuteStyle: 'walking',
          duration: 180,
          interests: [],
        );
        
        expect(request.interests, isEmpty);
      });

      test('should handle very long feedback text', () {
        final longFeedback = 'A' * 1000; // 1000 character string
        
        final updateRequest = ItineraryUpdateRequest(
          itineraryId: 'itinerary_123',
          locationId: 'loc_1',
          feedback: longFeedback,
        );
        
        expect(updateRequest.feedback.length, 1000);
      });

      test('should handle special characters in addresses', () {
        const specialAddresses = [
          'Champs-Élysées, Paris',
          'São Paulo, Brazil',
          'Москва, Russia',
          '東京, Japan',
          'القاهرة, Egypt'
        ];

        for (final address in specialAddresses) {
          final location = Location(
            latitude: 0,
            longitude: 0,
            address: address,
          );
          
          expect(location.address, address);
          expect(location.address.isNotEmpty, true);
        }
      });

      test('should handle itinerary with many locations', () {
        final locations = List.generate(20, (index) {
          final location = Location(
            latitude: 48.8566 + (index * 0.001),
            longitude: 2.3522 + (index * 0.001),
            address: 'Location $index',
          );

          return ItineraryLocation(
            id: 'loc_$index',
            name: 'Location $index',
            description: 'Description for location $index',
            location: location,
            duration: 30 + (index * 5),
            category: ['museum', 'historical', 'nature'][index % 3],
            travelTime: 10 + (index * 2),
            travelDistance: 0.2 + (index * 0.1),
            order: index,
          );
        });

        final itinerary = Itinerary(
          itineraryId: 'large_itinerary',
          locations: locations,
          totalDuration: locations.fold(0, (sum, loc) => sum + loc.duration + loc.travelTime),
          commuteStyle: 'walking',
        );

        expect(itinerary.locations.length, 20);
        expect(itinerary.locations.first.order, 0);
        expect(itinerary.locations.last.order, 19);
        expect(itinerary.totalDuration > 0, true);
      });
    });
  });
}