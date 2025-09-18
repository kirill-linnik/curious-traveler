import 'package:flutter_test/flutter_test.dart';
import 'package:curious_traveler/services/api_service.dart';
import 'package:curious_traveler/models/itinerary_models.dart';

void main() {
  group('API Service Integration Tests', () {
    test('should successfully create an itinerary job', () async {
      final apiService = ApiService();
      
      final request = ItineraryJobRequest(
        start: LocationPoint(
          lat: 37.7749,
          lon: -122.4194,
          address: 'San Francisco, CA',
        ),
        end: LocationPoint(
          lat: 37.7849,
          lon: -122.4094,
          address: 'Downtown San Francisco, CA',
        ),
        interests: 'museums, parks, restaurants',
        language: 'en',
        maxDurationMinutes: 480,
        mode: TravelMode.walking,
      );

      print('Creating itinerary job with request: ${request.toJson()}');
      
      final response = await apiService.createItineraryJob(request);
      
      print('Response: ${response.toJson()}');
      
      expect(response.jobId, isNotEmpty);
      expect(response.status, equals(JobStatus.processing));
    });
  });
}