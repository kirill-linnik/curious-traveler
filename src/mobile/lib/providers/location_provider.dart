import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/itinerary_models.dart';

class LocationProvider extends ChangeNotifier {
  Location? _currentLocation;
  bool _isLoading = false;
  String? _error;

  Location? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      _error = 'Failed to request location permission: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentLocation = Location(
        latitude: position.latitude,
        longitude: position.longitude,
        address: await _getAddressFromCoordinates(position.latitude, position.longitude),
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentLocation = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    // In a real app, you would use a geocoding service here
    // For now, return a placeholder
    return '$latitude, $longitude';
  }

  Future<double> getDistanceBetween(Location from, Location to) async {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}