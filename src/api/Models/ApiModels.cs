using System.Text.Json.Serialization;

namespace CuriousTraveler.Api.Models;

// Geocoding Models
public class ReverseGeocodeResponse
{
    [JsonPropertyName("formattedAddress")]
    public string FormattedAddress { get; set; } = string.Empty;
    
    [JsonPropertyName("locality")]
    public string Locality { get; set; } = string.Empty;
    
    [JsonPropertyName("countryCode")]
    public string CountryCode { get; set; } = string.Empty;
    
    [JsonPropertyName("center")]
    public GeocodePosition Center { get; set; } = new();
}

public class GeocodeSearchResult
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
    
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty; // "POI", "Address", "Locality"
    
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("formattedAddress")]
    public string FormattedAddress { get; set; } = string.Empty;
    
    [JsonPropertyName("locality")]
    public string Locality { get; set; } = string.Empty;
    
    [JsonPropertyName("countryCode")]
    public string CountryCode { get; set; } = string.Empty;
    
    [JsonPropertyName("position")]
    public GeocodePosition Position { get; set; } = new();
    
    [JsonPropertyName("confidence")]
    public string Confidence { get; set; } = string.Empty;
    
    [JsonPropertyName("bbox")]
    public BoundingBox? BoundingBox { get; set; }
}

public class GeocodePosition
{
    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }
    
    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }
}

public class BoundingBox
{
    [JsonPropertyName("southLatitude")]
    public double SouthLatitude { get; set; }
    
    [JsonPropertyName("westLongitude")]
    public double WestLongitude { get; set; }
    
    [JsonPropertyName("northLatitude")]
    public double NorthLatitude { get; set; }
    
    [JsonPropertyName("eastLongitude")]
    public double EastLongitude { get; set; }
}

// Itinerary Models
public class GenerateItineraryRequest
{
    [JsonPropertyName("destination")]
    public string Destination { get; set; } = string.Empty;
    
    [JsonPropertyName("days")]
    public int Days { get; set; }
    
    [JsonPropertyName("budget")]
    public string Budget { get; set; } = string.Empty;
    
    [JsonPropertyName("interests")]
    public List<string> Interests { get; set; } = new();
    
    [JsonPropertyName("language")]
    public string Language { get; set; } = "en";
}

public class ItineraryResponse
{
    [JsonPropertyName("destination")]
    public string Destination { get; set; } = string.Empty;
    
    [JsonPropertyName("totalDays")]
    public int TotalDays { get; set; }
    
    [JsonPropertyName("days")]
    public List<DayItinerary> Days { get; set; } = new();
    
    [JsonPropertyName("overview")]
    public string Overview { get; set; } = string.Empty;
    
    [JsonPropertyName("tips")]
    public List<string> Tips { get; set; } = new();
}

public class DayItinerary
{
    [JsonPropertyName("day")]
    public int Day { get; set; }
    
    [JsonPropertyName("theme")]
    public string Theme { get; set; } = string.Empty;
    
    [JsonPropertyName("activities")]
    public List<Activity> Activities { get; set; } = new();
    
    [JsonPropertyName("estimatedCost")]
    public decimal EstimatedCost { get; set; }
}

public class Activity
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;
    
    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;
    
    [JsonPropertyName("estimatedDuration")]
    public string EstimatedDuration { get; set; } = string.Empty;
    
    [JsonPropertyName("estimatedCost")]
    public decimal EstimatedCost { get; set; }
    
    [JsonPropertyName("location")]
    public ActivityLocation? Location { get; set; }
    
    [JsonPropertyName("timeOfDay")]
    public string TimeOfDay { get; set; } = string.Empty;
}

public class ActivityLocation
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("address")]
    public string Address { get; set; } = string.Empty;
    
    [JsonPropertyName("coordinates")]
    public GeocodePosition? Coordinates { get; set; }
}

// Speech Models
public class SpeechToTextRequest
{
    [JsonPropertyName("audioData")]
    public string AudioData { get; set; } = string.Empty; // Base64 encoded
    
    [JsonPropertyName("language")]
    public string Language { get; set; } = "en-US";
    
    [JsonPropertyName("format")]
    public string Format { get; set; } = "wav";
}

public class SpeechToTextResponse
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = string.Empty;
    
    [JsonPropertyName("confidence")]
    public double Confidence { get; set; }
    
    [JsonPropertyName("language")]
    public string Language { get; set; } = string.Empty;
}

public class TextToSpeechRequest
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = string.Empty;
    
    [JsonPropertyName("language")]
    public string Language { get; set; } = "en-US";
    
    [JsonPropertyName("voice")]
    public string Voice { get; set; } = "en-US-AriaNeural";
    
    [JsonPropertyName("speed")]
    public double Speed { get; set; } = 1.0;
}

public class TextToSpeechResponse
{
    [JsonPropertyName("audioData")]
    public string AudioData { get; set; } = string.Empty; // Base64 encoded
    
    [JsonPropertyName("contentType")]
    public string ContentType { get; set; } = "audio/wav";
}

// Error Models
public class ApiError
{
    [JsonPropertyName("error")]
    public string Error { get; set; } = string.Empty;
    
    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;
    
    [JsonPropertyName("traceId")]
    public string? TraceId { get; set; }
}

// Bing API Response Models (Internal)
internal class BingGeocodeResponse
{
    [JsonPropertyName("resourceSets")]
    public List<BingResourceSet> ResourceSets { get; set; } = new();
}

internal class BingResourceSet
{
    [JsonPropertyName("resources")]
    public List<BingLocation> Resources { get; set; } = new();
}

internal class BingLocation
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("point")]
    public BingPoint Point { get; set; } = new();
    
    [JsonPropertyName("address")]
    public BingAddress Address { get; set; } = new();
    
    [JsonPropertyName("confidence")]
    public string Confidence { get; set; } = string.Empty;
    
    [JsonPropertyName("bbox")]
    public List<double> BoundingBox { get; set; } = new();
    
    [JsonPropertyName("entityType")]
    public string EntityType { get; set; } = string.Empty;
}

internal class BingPoint
{
    [JsonPropertyName("coordinates")]
    public List<double> Coordinates { get; set; } = new();
}

internal class BingAddress
{
    [JsonPropertyName("formattedAddress")]
    public string FormattedAddress { get; set; } = string.Empty;
    
    [JsonPropertyName("locality")]
    public string Locality { get; set; } = string.Empty;
    
    [JsonPropertyName("countryRegion")]
    public string CountryRegion { get; set; } = string.Empty;
    
    [JsonPropertyName("countryRegionIso2")]
    public string CountryRegionIso2 { get; set; } = string.Empty;
}

internal class BingAutosuggestResponse
{
    [JsonPropertyName("resourceSets")]
    public List<BingAutosuggestResourceSet> ResourceSets { get; set; } = new();
}

internal class BingAutosuggestResourceSet
{
    [JsonPropertyName("resources")]
    public List<BingAutosuggestResource> Resources { get; set; } = new();
}

internal class BingAutosuggestResource
{
    [JsonPropertyName("value")]
    public List<BingAutosuggestValue> Value { get; set; } = new();
}

internal class BingAutosuggestValue
{
    [JsonPropertyName("__type")]
    public string Type { get; set; } = string.Empty;
    
    [JsonPropertyName("address")]
    public BingAddress? Address { get; set; }
    
    [JsonPropertyName("geocodePoints")]
    public List<BingGeocodePoint> GeocodePoints { get; set; } = new();
    
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("confidence")]
    public string Confidence { get; set; } = string.Empty;
}

internal class BingGeocodePoint
{
    [JsonPropertyName("coordinates")]
    public List<double> Coordinates { get; set; } = new();
}