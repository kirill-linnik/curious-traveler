import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'itinerary_models.g.dart';

@JsonSerializable()
class Location extends Equatable {
  final double latitude;
  final double longitude;
  final String address;

  const Location({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
  Map<String, dynamic> toJson() => _$LocationToJson(this);

  @override
  List<Object?> get props => [latitude, longitude, address];
}

@JsonSerializable(explicitToJson: true)
class ItineraryLocation extends Equatable {
  final String id;
  final String name;
  final String description;
  final Location location;
  final int duration;
  final String category;
  final int travelTime;
  final double travelDistance;
  final int order;

  const ItineraryLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.duration,
    required this.category,
    required this.travelTime,
    required this.travelDistance,
    required this.order,
  });

  factory ItineraryLocation.fromJson(Map<String, dynamic> json) => 
      _$ItineraryLocationFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryLocationToJson(this);

  @override
  List<Object?> get props => [
    id, name, description, location, duration, category, 
    travelTime, travelDistance, order
  ];
}

@JsonSerializable(explicitToJson: true)
class Itinerary extends Equatable {
  final String itineraryId;
  final List<ItineraryLocation> locations;
  final int totalDuration;
  final String commuteStyle;

  const Itinerary({
    required this.itineraryId,
    required this.locations,
    required this.totalDuration,
    required this.commuteStyle,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) => 
      _$ItineraryFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryToJson(this);

  @override
  List<Object?> get props => [itineraryId, locations, totalDuration, commuteStyle];
}

@JsonSerializable(explicitToJson: true)
class ItineraryRequest extends Equatable {
  final String city;
  final String commuteStyle;
  final int duration;
  final List<String> interests;
  final String language;
  final Location? startLocation;

  const ItineraryRequest({
    required this.city,
    required this.commuteStyle,
    required this.duration,
    required this.interests,
    this.language = 'en-US',
    this.startLocation,
  });

  factory ItineraryRequest.fromJson(Map<String, dynamic> json) => 
      _$ItineraryRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryRequestToJson(this);

  @override
  List<Object?> get props => [city, commuteStyle, duration, interests, language, startLocation];
}

@JsonSerializable(explicitToJson: true)
class ItineraryUpdateRequest extends Equatable {
  final String itineraryId;
  final String locationId;
  final String feedback;
  final Location? currentLocation;

  const ItineraryUpdateRequest({
    required this.itineraryId,
    required this.locationId,
    required this.feedback,
    this.currentLocation,
  });

  factory ItineraryUpdateRequest.fromJson(Map<String, dynamic> json) => 
      _$ItineraryUpdateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryUpdateRequestToJson(this);

  @override
  List<Object?> get props => [itineraryId, locationId, feedback, currentLocation];
}

enum CommuteStyle {
  walking('walking', 'Walking', Icons.directions_walk),
  transit('transit', 'Public Transit', Icons.directions_transit),
  driving('driving', 'Driving', Icons.directions_car);

  const CommuteStyle(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final IconData icon;
}

enum FeedbackType {
  like('like', 'Like', Icons.thumb_up),
  dislike('dislike', 'Dislike', Icons.thumb_down),
  moreTime('more_time', 'More Time', Icons.add_circle),
  lessTime('less_time', 'Less Time', Icons.remove_circle);

  const FeedbackType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final IconData icon;
}