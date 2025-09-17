import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/models/itinerary_models.dart';

void main() {
  group('Location Model Tests', () {
    test('should create Location from valid data', () {
      // Arrange
      const location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: '123 Main St, San Francisco, CA',
      );

      // Assert
      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
      expect(location.address, '123 Main St, San Francisco, CA');
    });

    test('should serialize to JSON correctly', () {
      // Arrange
      const location = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: '123 Main St, San Francisco, CA',
      );

      // Act
      final json = location.toJson();

      // Assert
      expect(json['latitude'], 37.7749);
      expect(json['longitude'], -122.4194);
      expect(json['address'], '123 Main St, San Francisco, CA');
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'latitude': 37.7749,
        'longitude': -122.4194,
        'address': '123 Main St, San Francisco, CA',
      };

      // Act
      final location = Location.fromJson(json);

      // Assert
      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
      expect(location.address, '123 Main St, San Francisco, CA');
    });

    test('should implement equality correctly', () {
      // Arrange
      const location1 = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: '123 Main St, San Francisco, CA',
      );
      const location2 = Location(
        latitude: 37.7749,
        longitude: -122.4194,
        address: '123 Main St, San Francisco, CA',
      );
      const location3 = Location(
        latitude: 40.7128,
        longitude: -74.0060,
        address: '456 Broadway, New York, NY',
      );

      // Assert
      expect(location1, equals(location2));
      expect(location1, isNot(equals(location3)));
    });
  });

  group('ItineraryLocation Model Tests', () {
    const testLocation = Location(
      latitude: 37.7749,
      longitude: -122.4194,
      address: '123 Main St, San Francisco, CA',
    );

    test('should create ItineraryLocation from valid data', () {
      // Arrange
      const itineraryLocation = ItineraryLocation(
        id: 'loc_1',
        name: 'Golden Gate Bridge',
        description: 'Famous suspension bridge',
        location: testLocation,
        duration: 60,
        category: 'landmark',
        travelTime: 15,
        travelDistance: 2500.0,
        order: 1,
      );

      // Assert
      expect(itineraryLocation.id, 'loc_1');
      expect(itineraryLocation.name, 'Golden Gate Bridge');
      expect(itineraryLocation.description, 'Famous suspension bridge');
      expect(itineraryLocation.location, testLocation);
      expect(itineraryLocation.duration, 60);
      expect(itineraryLocation.category, 'landmark');
      expect(itineraryLocation.travelTime, 15);
      expect(itineraryLocation.travelDistance, 2500.0);
      expect(itineraryLocation.order, 1);
    });

    test('should serialize to JSON correctly', () {
      // Arrange
      const itineraryLocation = ItineraryLocation(
        id: 'loc_1',
        name: 'Golden Gate Bridge',
        description: 'Famous suspension bridge',
        location: testLocation,
        duration: 60,
        category: 'landmark',
        travelTime: 15,
        travelDistance: 2500.0,
        order: 1,
      );

      // Act
      final json = itineraryLocation.toJson();

      // Assert
      expect(json['id'], 'loc_1');
      expect(json['name'], 'Golden Gate Bridge');
      expect(json['description'], 'Famous suspension bridge');
      expect(json['location'], isA<Map<String, dynamic>>());
      expect(json['location']['latitude'], 37.7749);
      expect(json['location']['longitude'], -122.4194);
      expect(json['location']['address'], '123 Main St, San Francisco, CA');
      expect(json['duration'], 60);
      expect(json['category'], 'landmark');
      expect(json['travelTime'], 15);
      expect(json['travelDistance'], 2500.0);
      expect(json['order'], 1);
    });

    test('should implement equality correctly', () {
      // Arrange
      const itineraryLocation1 = ItineraryLocation(
        id: 'loc_1',
        name: 'Golden Gate Bridge',
        description: 'Famous suspension bridge',
        location: testLocation,
        duration: 60,
        category: 'landmark',
        travelTime: 15,
        travelDistance: 2500.0,
        order: 1,
      );
      const itineraryLocation2 = ItineraryLocation(
        id: 'loc_1',
        name: 'Golden Gate Bridge',
        description: 'Famous suspension bridge',
        location: testLocation,
        duration: 60,
        category: 'landmark',
        travelTime: 15,
        travelDistance: 2500.0,
        order: 1,
      );
      const itineraryLocation3 = ItineraryLocation(
        id: 'loc_2',
        name: 'Alcatraz Island',
        description: 'Historic prison island',
        location: testLocation,
        duration: 120,
        category: 'attraction',
        travelTime: 30,
        travelDistance: 5000.0,
        order: 2,
      );

      // Assert
      expect(itineraryLocation1, equals(itineraryLocation2));
      expect(itineraryLocation1, isNot(equals(itineraryLocation3)));
    });
  });

  group('CommuteStyle Enum Tests', () {
    test('should have correct enum values', () {
      expect(CommuteStyle.walking.value, 'walking');
      expect(CommuteStyle.transit.value, 'transit');
      expect(CommuteStyle.driving.value, 'driving');
    });

    test('should find enum by value', () {
      // Test finding enum values by their string values
      expect(CommuteStyle.values.firstWhere((e) => e.value == 'walking'), CommuteStyle.walking);
      expect(CommuteStyle.values.firstWhere((e) => e.value == 'transit'), CommuteStyle.transit);
      expect(CommuteStyle.values.firstWhere((e) => e.value == 'driving'), CommuteStyle.driving);
    });

    test('should have correct display names', () {
      expect(CommuteStyle.walking.displayName, 'Walking');
      expect(CommuteStyle.transit.displayName, 'Public Transit');
      expect(CommuteStyle.driving.displayName, 'Driving');
    });

    test('should have correct icons', () {
      expect(CommuteStyle.walking.icon, Icons.directions_walk);
      expect(CommuteStyle.transit.icon, Icons.directions_transit);
      expect(CommuteStyle.driving.icon, Icons.directions_car);
    });
  });

  group('FeedbackType Enum Tests', () {
    test('should have correct enum values', () {
      expect(FeedbackType.like.value, 'like');
      expect(FeedbackType.dislike.value, 'dislike');
      expect(FeedbackType.moreTime.value, 'more_time');
      expect(FeedbackType.lessTime.value, 'less_time');
    });

    test('should find enum by value', () {
      // Test finding enum values by their string values
      expect(FeedbackType.values.firstWhere((e) => e.value == 'like'), FeedbackType.like);
      expect(FeedbackType.values.firstWhere((e) => e.value == 'dislike'), FeedbackType.dislike);
      expect(FeedbackType.values.firstWhere((e) => e.value == 'more_time'), FeedbackType.moreTime);
      expect(FeedbackType.values.firstWhere((e) => e.value == 'less_time'), FeedbackType.lessTime);
    });

    test('should have correct display names', () {
      expect(FeedbackType.like.displayName, 'Like');
      expect(FeedbackType.dislike.displayName, 'Dislike');
      expect(FeedbackType.moreTime.displayName, 'More Time');
      expect(FeedbackType.lessTime.displayName, 'Less Time');
    });

    test('should have correct icons', () {
      expect(FeedbackType.like.icon, Icons.thumb_up);
      expect(FeedbackType.dislike.icon, Icons.thumb_down);
      expect(FeedbackType.moreTime.icon, Icons.add_circle);
      expect(FeedbackType.lessTime.icon, Icons.remove_circle);
    });
  });
}