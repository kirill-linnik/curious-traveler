import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/itinerary_models.dart';
import '../models/location_models.dart';
import '../config/app_config.dart';

/// API Service for communicating with the Curious Traveler backend
/// 
/// Currently supports:
/// - ✅ Location search (geocoding) via ASP.NET Core Web API  
/// - ✅ Reverse geocoding via ASP.NET Core Web API
/// - ❌ Itinerary generation (not yet implemented)
/// - ❌ Audio generation (not yet implemented) 
/// - ❌ Location narration (not yet implemented)
class ApiService {
  // Using configuration constants instead of hard-coded values
  static String get _baseUrl => AppConfig.apiBaseUrl;

  final http.Client _client = http.Client();

  Map<String, String> _getHeaders() {
    return Map<String, String>.from(AppConfig.defaultHeaders);
  }

  Future<Itinerary> generateItinerary(ItineraryRequest request) async {
    try {
      // Note: Itinerary generation endpoint is not yet implemented in the Web API
      throw ApiException('Itinerary generation is not yet available', 501);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Itinerary generation error: $e', 0);
    }
  }

  Future<Itinerary> updateItinerary(ItineraryUpdateRequest request) async {
    try {
      // Note: Itinerary update endpoint is not yet implemented in the Web API
      throw ApiException('Itinerary update is not yet available', 501);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Itinerary update error: $e', 0);
    }
  }

  Future<String> getLocationNarration(String locationId, {String language = 'en-US'}) async {
    try {
      // Note: Location narration endpoint is not yet implemented in the Web API
      throw ApiException('Location narration is not yet available', 501);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Narration error: $e', 0);
    }
  }

  Future<Uint8List> generateAudio(String text, {String language = 'en-US'}) async {
    try {
      // Note: Audio generation endpoint is not yet implemented in the Web API
      throw ApiException('Audio generation is not yet available', 501);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Audio generation error: $e', 0);
    }
  }

  Future<String> getSupportedVoice({String language = 'en-US'}) async {
    try {
      // Note: Voice support endpoint is not yet implemented in the Web API
      throw ApiException('Voice support check is not yet available', 501);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Voice support error: $e', 0);
    }
  }

  Future<ReverseGeocodeResult?> reverseGeocode(double latitude, double longitude, {String language = 'en'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/geocode/reverse').replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'lang': language,
      });

      final response = await _client.get(
        uri,
        headers: _getHeaders(),
      ).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ReverseGeocodeResult.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        return null; // No location found
      } else {
        throw ApiException(
          'Failed to reverse geocode: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Reverse geocode error: $e', 0);
    }
  }

  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    String language = 'en',
    double? latitude,
    double? longitude,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'query': query,
        'lang': language,
        'limit': limit.toString(),
      };

      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
      }

      final uri = Uri.parse('$_baseUrl/geocode/search').replace(queryParameters: queryParams);

      final response = await _client.get(
        uri,
        headers: _getHeaders(),
      ).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List<dynamic>;
        return jsonData
            .map((item) => LocationSearchResult.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to search locations: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Location search error: $e', 0);
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}