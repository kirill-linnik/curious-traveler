using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using Azure;

namespace CuriousTraveler.Api.Models.Itinerary;

public enum JobStatus
{
    Processing,
    Completed,
    Failed
}

public enum FailureReason
{
    CommuteExceedsBudget,
    NoOpenPois,
    NoPoisInIsochrone,
    RoutingFailed,
    InternalError
}

public enum TravelMode
{
    Walking,
    PublicTransport,
    Car
}

public class ItineraryRequest
{
    [Required]
    public required LocationPoint Start { get; set; }
    
    [Required]
    public required LocationPoint End { get; set; }
    
    [Range(60, 720)] // 1 hour to 12 hours
    public int MaxDurationMinutes { get; set; }
    
    [Required]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public TravelMode Mode { get; set; }
    
    [Required]
    [StringLength(500)]
    public required string Interests { get; set; }
    
    [Required]
    [StringLength(10)]
    public required string Language { get; set; } = "en";
}

public class LocationPoint
{
    [Range(-90, 90)]
    public double Lat { get; set; }
    
    [Range(-180, 180)]
    public double Lon { get; set; }
    
    public string? Address { get; set; }
}

public class ItineraryJobResponse
{
    public required string JobId { get; set; }
    
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public JobStatus Status { get; set; }
    
    public ItineraryResult? Result { get; set; }
    
    public ItineraryError? Error { get; set; }
}

public class ItineraryResult
{
    public required ItinerarySummary Summary { get; set; }
    public required List<ItineraryLeg> Legs { get; set; }
    public required List<ItineraryStop> Stops { get; set; }
}

public class ItinerarySummary
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public TravelMode Mode { get; set; }
    
    public required string Language { get; set; }
    
    public int TimeBudgetMinutes { get; set; }
    
    public int TotalDistanceMeters { get; set; }
    
    public int TotalTravelMinutes { get; set; }
    
    public int TotalVisitMinutes { get; set; }
    
    public int StopsCount { get; set; }
}

public class ItineraryLeg
{
    public required string From { get; set; }
    
    public required string To { get; set; }
    
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public TravelMode Mode { get; set; }
    
    public int DistanceMeters { get; set; }
    
    public int TravelMinutes { get; set; }
    
    public int DepartFromJourneyStart { get; set; }
    
    public int ArriveFromJourneyStart { get; set; }
}

public class ItineraryStop
{
    public required string Id { get; set; }
    
    public required string Name { get; set; }
    
    public required string Address { get; set; }
    
    public double Lat { get; set; }
    
    public double Lon { get; set; }
    
    public required string Description { get; set; }
    
    public int VisitMinutes { get; set; }
    
    public int ArriveFromJourneyStart { get; set; }
    
    public int DepartFromJourneyStart { get; set; }
    
    public string? Category { get; set; }
    
    public double? Rating { get; set; }
}

public class ItineraryError
{
    public required string Code { get; set; }
    
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public FailureReason Reason { get; set; }
    
    public string? Message { get; set; }
}

// Internal models for processing

public class ItineraryJob
{
    public required string JobId { get; set; }
    
    public JobStatus Status { get; set; }
    
    public required ItineraryRequest Request { get; set; }
    
    public DateTime CreatedAt { get; set; }
    
    public DateTime? CompletedAt { get; set; }
    
    public string? ResultJson { get; set; }
    
    public FailureReason? FailureReason { get; set; }
    
    public string? ErrorMessage { get; set; }
    
    public int ProcessingAttempts { get; set; }
    
    public DateTime ExpiresAt { get; set; }
    
    /// <summary>
    /// ETag for optimistic concurrency control in table storage
    /// </summary>
    public Azure.ETag? ETag { get; set; }
}

public class PointOfInterest
{
    public required string Id { get; set; }
    
    public required string Name { get; set; }
    
    public required string Address { get; set; }
    
    public double Latitude { get; set; }
    
    public double Longitude { get; set; }
    
    public string? Category { get; set; }
    
    public double? Rating { get; set; }
    
    public int? ReviewCount { get; set; }
    
    public List<string> Tags { get; set; } = [];
    
    public string? Description { get; set; }
    
    public OpeningHours? OpeningHours { get; set; }
    
    public int DistanceFromStartMeters { get; set; }
    
    public int EstimatedMinVisitMinutes { get; set; }
    
    public bool IsOpenAt(DateTime dateTime) => OpeningHours?.IsOpenAt(dateTime) ?? true;
}

public class OpeningHours
{
    public required List<DaySchedule> Schedule { get; set; }
    
    public bool IsOpenAt(DateTime dateTime)
    {
        var dayOfWeek = (int)dateTime.DayOfWeek;
        var daySchedule = Schedule.FirstOrDefault(s => s.DayOfWeek == dayOfWeek);
        
        if (daySchedule == null || !daySchedule.IsOpen)
            return false;
            
        var timeOfDay = dateTime.TimeOfDay;
        return timeOfDay >= daySchedule.OpenTime && timeOfDay <= daySchedule.CloseTime;
    }
}

public class DaySchedule
{
    public int DayOfWeek { get; set; } // 0 = Sunday, 1 = Monday, etc.
    
    public bool IsOpen { get; set; }
    
    public TimeSpan OpenTime { get; set; }
    
    public TimeSpan CloseTime { get; set; }
}