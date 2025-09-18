import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/itinerary_models.dart';
import '../services/api_service.dart';
import '../services/itinerary_job_service.dart';
import 'enhanced_location_provider.dart';

class ItineraryProvider extends ChangeNotifier {
  final ApiService _apiService;
  final ItineraryJobService _jobService;
  final EnhancedLocationProvider _locationProvider;

  // Legacy support
  Itinerary? _currentItinerary;
  
  // New job-based system
  ItineraryResult? _currentResult;
  String? _currentJobId;
  JobStatus? _jobStatus;
  String? _statusMessage;
  
  // Store original start/end addresses from user selection
  String? _originalStartAddress;
  String? _originalEndAddress;
  
  bool _isLoading = false;
  String? _error;
  StreamSubscription<ItineraryJobResponse>? _jobSubscription;

  ItineraryProvider(this._apiService, this._locationProvider) 
      : _jobService = ItineraryJobService(_apiService);

  // Legacy getters for backward compatibility
  Itinerary? get currentItinerary => _currentItinerary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // New getters for job-based system
  ItineraryResult? get currentResult => _currentResult;
  String? get currentJobId => _currentJobId;
  JobStatus? get jobStatus => _jobStatus;
  String? get statusMessage => _statusMessage;
  
  // Getters for original start/end addresses
  String? get originalStartAddress => _originalStartAddress;
  String? get originalEndAddress => _originalEndAddress;
  
  // Helper getter to check if we have any itinerary data
  bool get hasItinerary => _currentItinerary != null || _currentResult != null;

  // Convert new result to legacy format for backward compatibility
  List<ItineraryLocation> get sortedLocations {
    if (_currentResult != null) {
      return _convertToLegacyLocations(_currentResult!);
    }
    if (_currentItinerary != null) {
      final locations = List<ItineraryLocation>.from(_currentItinerary!.locations);
      locations.sort((a, b) => a.order.compareTo(b.order));
      return locations;
    }
    return [];
  }

  /// Convert ItineraryResult to legacy ItineraryLocation list
  List<ItineraryLocation> _convertToLegacyLocations(ItineraryResult result) {
    return result.stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      
      return ItineraryLocation(
        id: stop.id,
        name: stop.name,
        description: stop.description,
        location: Location(
          latitude: stop.lat,
          longitude: stop.lon,
          address: stop.address,
        ),
        duration: stop.visitMinutes,
        category: stop.category ?? 'attraction',
        travelTime: index < result.legs.length ? result.legs[index].travelMinutes : 0,
        travelDistance: index < result.legs.length ? result.legs[index].distanceMeters.toDouble() : 0.0,
        order: index + 1,
      );
    }).toList();
  }

  /// Convert ItineraryResult to legacy Itinerary
  Itinerary _convertToLegacyItinerary(ItineraryResult result) {
    return Itinerary(
      itineraryId: _currentJobId ?? 'job_${DateTime.now().millisecondsSinceEpoch}',
      locations: _convertToLegacyLocations(result),
      totalDuration: result.summary.totalVisitMinutes + result.summary.totalTravelMinutes,
      commuteStyle: result.summary.mode.displayName.toLowerCase(),
    );
  }

  Future<void> generateItineraryWithJob({
    required LocationPoint start,
    required LocationPoint end,
    required List<String> interests,
    required TravelMode mode,
    required int durationHours,
    String language = 'en',
  }) async {
    print('DEBUG: ItineraryProvider.generateItineraryWithJob called');
    print('DEBUG: Start: ${start.toJson()}');
    print('DEBUG: End: ${end.toJson()}');
    print('DEBUG: Interests: $interests');
    print('DEBUG: Mode: $mode');
    print('DEBUG: Duration: $durationHours hours');
    print('DEBUG: Language: $language');
    
    _isLoading = true;
    _error = null;
    _statusMessage = 'Creating itinerary job...';
    _jobStatus = null;
    
    // Store original start and end addresses
    _originalStartAddress = start.address;
    _originalEndAddress = end.address;
    
    notifyListeners();

    try {
      print('DEBUG: Creating ItineraryJobRequest...');
      final request = ItineraryJobRequest(
        start: start,
        end: end,
        interests: interests.join(', '),
        language: language,
        maxDurationMinutes: durationHours * 60,
        mode: mode,
      );
      
      print('DEBUG: Request created: ${request.toJson()}');

      // Cancel any existing job subscription
      print('DEBUG: Cancelling existing job subscription...');
      await _jobSubscription?.cancel();

      // Start the job and listen to updates
      print('DEBUG: Starting job creation and polling...');
      _jobSubscription = _jobService.createAndPollItineraryJob(request).listen(
        (response) {
          print('DEBUG: Received job response: ${response.toJson()}');
          _currentJobId = response.jobId;
          _jobStatus = response.status;
          
          switch (response.status) {
            case JobStatus.processing:
              print('DEBUG: Job is processing...');
              _statusMessage = 'Itinerary is being prepared, please wait...';
              break;
            case JobStatus.completed:
              print('DEBUG: Job completed successfully!');
              _statusMessage = 'Itinerary completed successfully!';
              _currentResult = response.result;
              _isLoading = false;
              
              // Create legacy itinerary for backward compatibility
              if (response.result != null) {
                print('DEBUG: Converting result to legacy format...');
                _currentItinerary = _convertToLegacyItinerary(response.result!);
                print('DEBUG: Legacy conversion successful, ${_currentItinerary!.locations.length} locations');
              }
              break;
            case JobStatus.failed:
              print('DEBUG: Job failed: ${response.error?.message ?? response.error?.reason.displayMessage ?? "Unknown error"}');
              _statusMessage = 'Failed to create itinerary';
              _error = response.error?.message ?? response.error?.reason.displayMessage ?? 'Unknown error occurred';
              _isLoading = false;
              break;
          }
          notifyListeners();
        },
        onError: (error) {
          print('DEBUG: Job stream error: $error');
          _isLoading = false;
          _error = error.toString();
          _statusMessage = 'Error occurred while creating itinerary';
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      print('DEBUG: Exception in generateItineraryWithJob: $e');
      print('DEBUG: Stack trace: $stackTrace');
      _isLoading = false;
      _error = e.toString();
      _statusMessage = 'Failed to start itinerary creation';
      notifyListeners();
    }
  }

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
    
    for (final location in _currentItinerary!.locations) {
      if (location.id == locationId) {
        return location;
      }
    }
    return null;
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