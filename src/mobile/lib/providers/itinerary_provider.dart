import 'package:flutter/foundation.dart';
import '../models/itinerary_models.dart';
import '../services/api_service.dart';
import 'enhanced_location_provider.dart';

class ItineraryProvider extends ChangeNotifier {
  final ApiService _apiService;
  final EnhancedLocationProvider _locationProvider;

  Itinerary? _currentItinerary;
  bool _isLoading = false;
  String? _error;

  ItineraryProvider(this._apiService, this._locationProvider);

  Itinerary? get currentItinerary => _currentItinerary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> generateItinerary({
    required String city,
    required CommuteStyle commuteStyle,
    required int duration,
    required List<String> interests,
    String language = 'en-US',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = ItineraryRequest(
        city: city,
        commuteStyle: commuteStyle.value,
        duration: duration,
        interests: interests,
        language: language,
        startLocation: _locationProvider.currentLocation,
      );

      _currentItinerary = await _apiService.generateItinerary(request);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentItinerary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateItinerary({
    required String locationId,
    required FeedbackType feedback,
  }) async {
    if (_currentItinerary == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = ItineraryUpdateRequest(
        itineraryId: _currentItinerary!.itineraryId,
        locationId: locationId,
        feedback: feedback.value,
        currentLocation: _locationProvider.currentLocation,
      );

      _currentItinerary = await _apiService.updateItinerary(request);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> getLocationNarration(String locationId, {String language = 'en-US'}) async {
    try {
      return await _apiService.getLocationNarration(locationId, language: language);
    } catch (e) {
      debugPrint('Error getting narration: $e');
      return 'Unable to load narration for this location.';
    }
  }

  void clearItinerary() {
    _currentItinerary = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ItineraryLocation? getLocationById(String locationId) {
    if (_currentItinerary == null) return null;
    
    try {
      return _currentItinerary!.locations.firstWhere(
        (location) => location.id == locationId,
      );
    } catch (e) {
      return null;
    }
  }

  List<ItineraryLocation> get sortedLocations {
    if (_currentItinerary == null) return [];
    
    final locations = List<ItineraryLocation>.from(_currentItinerary!.locations);
    locations.sort((a, b) => a.order.compareTo(b.order));
    return locations;
  }

  int get totalTravelTime {
    if (_currentItinerary == null) return 0;
    return _currentItinerary!.locations.fold(0, (sum, location) => sum + location.travelTime);
  }

  double get totalDistance {
    if (_currentItinerary == null) return 0.0;
    return _currentItinerary!.locations.fold(0.0, (sum, location) => sum + location.travelDistance);
  }

  // Test helper methods - only available in debug mode
  @visibleForTesting
  void debugSetItinerary(Itinerary itinerary) {
    _currentItinerary = itinerary;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetError(String error) {
    _error = error;
    notifyListeners();
  }
}