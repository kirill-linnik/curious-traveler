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

// ============================================================================
// NEW JOB-BASED API MODELS
// ============================================================================

@JsonSerializable(explicitToJson: true)
class LocationPoint extends Equatable {
  @JsonKey(name: 'Lat')
  final double lat;
  @JsonKey(name: 'Lon')
  final double lon;
  @JsonKey(name: 'Address')
  final String? address;

  const LocationPoint({
    required this.lat,
    required this.lon,
    this.address,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) => _$LocationPointFromJson(json);
  Map<String, dynamic> toJson() => _$LocationPointToJson(this);

  @override
  List<Object?> get props => [lat, lon, address];
}

enum JobStatus {
  @JsonValue('Processing')
  processing,
  @JsonValue('Completed')
  completed,
  @JsonValue('Failed')
  failed,
}

enum TravelMode {
  @JsonValue('Walking')
  walking,
  @JsonValue('PublicTransport')
  publicTransport,
  @JsonValue('Car')
  car,
}

@JsonSerializable(explicitToJson: true)
class ItineraryJobRequest extends Equatable {
  final LocationPoint start;
  final LocationPoint end;
  final String interests;
  final String language;
  final int maxDurationMinutes;
  final TravelMode mode;

  const ItineraryJobRequest({
    required this.start,
    required this.end,
    required this.interests,
    required this.language,
    required this.maxDurationMinutes,
    required this.mode,
  });

  factory ItineraryJobRequest.fromJson(Map<String, dynamic> json) => _$ItineraryJobRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryJobRequestToJson(this);

  @override
  List<Object?> get props => [start, end, interests, language, maxDurationMinutes, mode];
}

@JsonSerializable(explicitToJson: true)
class ItineraryJobResponse extends Equatable {
  final String jobId;
  final JobStatus status;
  final ItineraryResult? result;
  final ItineraryError? error;

  const ItineraryJobResponse({
    required this.jobId,
    required this.status,
    this.result,
    this.error,
  });

  factory ItineraryJobResponse.fromJson(Map<String, dynamic> json) => _$ItineraryJobResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryJobResponseToJson(this);

  @override
  List<Object?> get props => [jobId, status, result, error];
}

@JsonSerializable(explicitToJson: true)
class ItineraryResult extends Equatable {
  final ItinerarySummary summary;
  final List<ItineraryLeg> legs;
  final List<ItineraryStop> stops;

  const ItineraryResult({
    required this.summary,
    required this.legs,
    required this.stops,
  });

  factory ItineraryResult.fromJson(Map<String, dynamic> json) => _$ItineraryResultFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryResultToJson(this);

  @override
  List<Object?> get props => [summary, legs, stops];
}

@JsonSerializable(explicitToJson: true)
class ItinerarySummary extends Equatable {
  @JsonKey(name: 'mode')
  final TravelMode mode;
  @JsonKey(name: 'language')
  final String language;
  @JsonKey(name: 'timeBudgetMinutes')
  final int timeBudgetMinutes;
  @JsonKey(name: 'totalDistanceMeters')
  final int totalDistanceMeters;
  @JsonKey(name: 'totalTravelMinutes')
  final int totalTravelMinutes;
  @JsonKey(name: 'totalVisitMinutes')
  final int totalVisitMinutes;
  @JsonKey(name: 'stopsCount')
  final int stopsCount;

  const ItinerarySummary({
    required this.mode,
    required this.language,
    required this.timeBudgetMinutes,
    required this.totalDistanceMeters,
    required this.totalTravelMinutes,
    required this.totalVisitMinutes,
    required this.stopsCount,
  });

  factory ItinerarySummary.fromJson(Map<String, dynamic> json) => _$ItinerarySummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ItinerarySummaryToJson(this);

  @override
  List<Object?> get props => [mode, language, timeBudgetMinutes, totalDistanceMeters, totalTravelMinutes, totalVisitMinutes, stopsCount];
}

@JsonSerializable(explicitToJson: true)
class ItineraryLeg extends Equatable {
  @JsonKey(name: 'from')
  final String from;
  @JsonKey(name: 'to')
  final String to;
  @JsonKey(name: 'mode')
  final TravelMode mode;
  @JsonKey(name: 'distanceMeters')
  final int distanceMeters;
  @JsonKey(name: 'travelMinutes')
  final int travelMinutes;
  @JsonKey(name: 'departFromJourneyStart')
  final int departFromJourneyStart;
  @JsonKey(name: 'arriveFromJourneyStart')
  final int arriveFromJourneyStart;

  const ItineraryLeg({
    required this.from,
    required this.to,
    required this.mode,
    required this.distanceMeters,
    required this.travelMinutes,
    required this.departFromJourneyStart,
    required this.arriveFromJourneyStart,
  });

  factory ItineraryLeg.fromJson(Map<String, dynamic> json) => _$ItineraryLegFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryLegToJson(this);

  @override
  List<Object?> get props => [from, to, mode, distanceMeters, travelMinutes, departFromJourneyStart, arriveFromJourneyStart];
}

@JsonSerializable(explicitToJson: true)
class ItineraryStop extends Equatable {
  @JsonKey(name: 'id')
  final String id;
  @JsonKey(name: 'name')
  final String name;
  @JsonKey(name: 'address')
  final String address;
  @JsonKey(name: 'lat')
  final double lat;
  @JsonKey(name: 'lon')
  final double lon;
  @JsonKey(name: 'description')
  final String description;
  @JsonKey(name: 'visitMinutes')
  final int visitMinutes;
  @JsonKey(name: 'arriveFromJourneyStart')
  final int arriveFromJourneyStart;
  @JsonKey(name: 'departFromJourneyStart')
  final int departFromJourneyStart;
  @JsonKey(name: 'category')
  final String? category;
  @JsonKey(name: 'rating')
  final double? rating;

  const ItineraryStop({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.description,
    required this.visitMinutes,
    required this.arriveFromJourneyStart,
    required this.departFromJourneyStart,
    this.category,
    this.rating,
  });

  factory ItineraryStop.fromJson(Map<String, dynamic> json) => _$ItineraryStopFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryStopToJson(this);

  @override
  List<Object?> get props => [id, name, address, lat, lon, description, visitMinutes, arriveFromJourneyStart, departFromJourneyStart, category, rating];
}

enum FailureReason {
  @JsonValue('CommuteExceedsBudget')
  commuteExceedsBudget,
  @JsonValue('NoOpenPois')
  noOpenPois,
  @JsonValue('NoPoisInIsochrone')
  noPoisInIsochrone,
  @JsonValue('RoutingFailed')
  routingFailed,
  @JsonValue('InternalError')
  internalError,
}

@JsonSerializable(explicitToJson: true)
class ItineraryError extends Equatable {
  final String code;
  final FailureReason reason;
  final String message;

  const ItineraryError({
    required this.code,
    required this.reason,
    required this.message,
  });

  factory ItineraryError.fromJson(Map<String, dynamic> json) => _$ItineraryErrorFromJson(json);
  Map<String, dynamic> toJson() => _$ItineraryErrorToJson(this);

  @override
  List<Object?> get props => [code, reason, message];
}

// Extension to convert CommuteStyle to TravelMode
extension TravelModeExtension on TravelMode {
  static TravelMode fromCommuteStyle(CommuteStyle style) {
    switch (style) {
      case CommuteStyle.walking:
        return TravelMode.walking;
      case CommuteStyle.transit:
        return TravelMode.publicTransport;
      case CommuteStyle.driving:
        return TravelMode.car;
    }
  }
  
  String get displayName {
    switch (this) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.publicTransport:
        return 'Public Transport';
      case TravelMode.car:
        return 'Car';
    }
  }
  
  IconData get icon {
    switch (this) {
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.publicTransport:
        return Icons.directions_transit;
      case TravelMode.car:
        return Icons.directions_car;
    }
  }
}

extension FailureReasonExtension on FailureReason {
  String get displayMessage {
    switch (this) {
      case FailureReason.commuteExceedsBudget:
        return 'Commute exceeds time budget';
      case FailureReason.noOpenPois:
        return 'No open points of interest found';
      case FailureReason.noPoisInIsochrone:
        return 'No points of interest in reachable area';
      case FailureReason.routingFailed:
        return 'Route planning failed';
      case FailureReason.internalError:
        return 'Internal server error';
    }
  }
}