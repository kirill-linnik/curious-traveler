import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class LocationSearchResult extends Equatable {
  final String id;
  final String type; // "POI", "Address", "Locality"
  final String name;
  final String formattedAddress;
  final String locality;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String confidence;

  const LocationSearchResult({
    required this.id,
    required this.type,
    required this.name,
    required this.formattedAddress,
    required this.locality,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.confidence,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>? ?? {};
    return LocationSearchResult(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      latitude: (position['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (position['longitude'] as num?)?.toDouble() ?? 0.0,
      confidence: json['confidence'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'formattedAddress': formattedAddress,
    'locality': locality,
    'countryCode': countryCode,
    'position': {
      'latitude': latitude,
      'longitude': longitude,
    },
    'confidence': confidence,
  };

  @override
  List<Object?> get props => [id, type, name, formattedAddress, locality, countryCode, latitude, longitude, confidence];

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'locality':
        return Icons.location_city;
      case 'address':
        return Icons.home;
      case 'poi':
        return Icons.place;
      default:
        return Icons.location_on;
    }
  }
}

class ReverseGeocodeResult extends Equatable {
  final String formattedAddress;
  final String locality;
  final String countryCode;
  final double latitude;
  final double longitude;

  const ReverseGeocodeResult({
    required this.formattedAddress,
    required this.locality,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>? ?? {};
    return ReverseGeocodeResult(
      formattedAddress: json['formattedAddress'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      latitude: (center['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (center['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'formattedAddress': formattedAddress,
    'locality': locality,
    'countryCode': countryCode,
    'center': {
      'latitude': latitude,
      'longitude': longitude,
    },
  };

  @override
  List<Object?> get props => [formattedAddress, locality, countryCode, latitude, longitude];
}

enum LocationMode {
  currentLocation,
  anotherLocation,
}

enum LocationStatus {
  unknown,
  detecting,
  detected,
  failed,
  searching,
  searchComplete,
  searchFailed,
}

/// Selection model for search results - replaces old LocationSearchResult usage
class LocationSelection extends Equatable {
  final String id; // stable ID
  final String type; // "POI" | "Address" | "Locality"
  final String name;
  final String? fullAddress;
  final String? locality;
  final ({ double lat, double lon }) position;
  final ({ double north, double south, double east, double west })? bbox;

  const LocationSelection({
    required this.id,
    required this.type,
    required this.name,
    this.fullAddress,
    this.locality,
    required this.position,
    this.bbox,
  });

  factory LocationSelection.fromSearchResult(LocationSearchResult result) {
    return LocationSelection(
      id: result.id,
      type: result.type,
      name: result.name,
      fullAddress: result.formattedAddress.isNotEmpty ? result.formattedAddress : null,
      locality: result.locality.isNotEmpty ? result.locality : null,
      position: (lat: result.latitude, lon: result.longitude),
      bbox: null, // Can be added later if needed
    );
  }

  @override
  List<Object?> get props => [id, type, name, fullAddress, locality, position, bbox];
}

/// Immutable snapshot of a location detection result
/// Used to store current location data for the lifetime of a Home screen instance
class LocationSnapshot extends Equatable {
  final String displayText; // formatted address
  final String? locality;
  final ({ double lat, double lon })? position;

  const LocationSnapshot({
    required this.displayText,
    this.locality,
    this.position,
  });

  factory LocationSnapshot.fromCurrentLocation({
    required String displayText,
    String? locality,
    required double latitude,
    required double longitude,
  }) {
    return LocationSnapshot(
      displayText: displayText,
      locality: locality,
      position: (lat: latitude, lon: longitude),
    );
  }

  factory LocationSnapshot.fromSearchResult({
    required LocationSearchResult result,
  }) {
    return LocationSnapshot(
      displayText: result.formattedAddress.isNotEmpty ? result.formattedAddress : result.name,
      locality: result.locality.isNotEmpty ? result.locality : null,
      position: (lat: result.latitude, lon: result.longitude),
    );
  }

  @override
  List<Object?> get props => [displayText, locality, position];
}

/// Position data for a location
class LocationPosition extends Equatable {
  final double latitude;
  final double longitude;

  const LocationPosition({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [latitude, longitude];
}