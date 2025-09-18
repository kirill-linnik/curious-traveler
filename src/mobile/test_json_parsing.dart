import 'dart:convert';
import 'lib/models/itinerary_models.dart';

void main() {
  // This simulates the actual API response that was failing
  final jsonResponse = '''
{
  "jobId": "fe0f283b-42bb-49b9-a2d2-d6c2b968938a",
  "status": "Completed",
  "result": {
    "summary": {
      "mode": "Walking",
      "language": "en",
      "timeBudgetMinutes": 180,
      "totalDistanceMeters": 5542,
      "totalTravelMinutes": 65,
      "totalVisitMinutes": 114,
      "stopsCount": 2
    },
    "legs": [{
      "from": "Start",
      "to": "Aleksander Nevski Katedraali",
      "mode": "Walking",
      "distanceMeters": 2495,
      "travelMinutes": 29,
      "departFromJourneyStart": 0,
      "arriveFromJourneyStart": 29
    }],
    "stops": [{
      "id": "fuzzy_98a67a6a780347538",
      "name": "Aleksander Nevski Katedraali",
      "address": "Lossi plats 10, 10130 Kesklinn, Tallinn",
      "lat": 59.435739,
      "lon": 24.739317,
      "description": "Test description",
      "visitMinutes": 47,
      "arriveFromJourneyStart": 29,
      "departFromJourneyStart": 76,
      "category": "important tourist attraction",
      "rating": 1.3665235281
    }]
  },
  "error": null
}
''';

  try {
    final jsonData = jsonDecode(jsonResponse) as Map<String, dynamic>;
    final response = ItineraryJobResponse.fromJson(jsonData);
    
    print('✅ SUCCESS: JSON parsing worked!');
    print('Job ID: ${response.jobId}');
    print('Status: ${response.status}');
    print('Mode: ${response.result?.summary.mode}');
    print('Language: ${response.result?.summary.language}');
    print('Stops count: ${response.result?.stops.length}');
    
  } catch (e, stackTrace) {
    print('❌ ERROR: JSON parsing failed');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}