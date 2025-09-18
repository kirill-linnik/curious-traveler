using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Models.AzureMaps;
using CuriousTraveler.Api.Models.Itinerary;

namespace CuriousTraveler.Api.Services;

/// <summary>
/// Interface for Azure Maps geocoding services
/// </summary>
public interface IAzureMapsService
{
    /// <summary>
    /// Performs reverse geocoding to convert coordinates to an address
    /// </summary>
    /// <param name="latitude">Latitude coordinate (-90 to 90)</param>
    /// <param name="longitude">Longitude coordinate (-180 to 180)</param>
    /// <param name="language">Language code for the response (optional)</param>
    /// <returns>Reverse geocoding result normalized to API contract</returns>
    Task<ReverseGeocodeResponse> ReverseGeocodeAsync(double latitude, double longitude, string? language = null);

    /// <summary>
    /// Performs forward geocoding/search for locations
    /// </summary>
    /// <param name="query">Search query for places, addresses, or POIs</param>
    /// <param name="language">Language code for the response (optional)</param>
    /// <param name="userLatitude">User's latitude for biasing results (optional)</param>
    /// <param name="userLongitude">User's longitude for biasing results (optional)</param>
    /// <param name="limit">Maximum number of results to return</param>
    /// <returns>List of geocoding search results normalized to API contract</returns>
    Task<List<GeocodeSearchResult>> SearchAsync(string query, string? language = null, double? userLatitude = null, double? userLongitude = null, int limit = 10);

    /// <summary>
    /// Gets an access token for Azure Maps (AAD mode only)
    /// </summary>
    /// <returns>Azure Maps access token with expiration time</returns>
    Task<AzureMapsToken> GetAccessTokenAsync();

    // New methods for itinerary planning

    /// <summary>
    /// Gets the local timezone for coordinates
    /// </summary>
    Task<TimeZoneInfo> GetTimeZoneAsync(double latitude, double longitude);

    /// <summary>
    /// Calculates route between two points
    /// </summary>
    Task<RouteResult> GetRouteAsync(LocationPoint start, LocationPoint end, TravelMode mode);

    /// <summary>
    /// Gets isochrone/reachability area from a point
    /// </summary>
    Task<IsochroneResult?> GetIsochroneAsync(LocationPoint center, TravelMode mode, int timeMinutes);

    /// <summary>
    /// Searches for POIs by category within a geographic area
    /// </summary>
    Task<List<PointOfInterest>> SearchPoisAsync(
        LocationPoint center,
        List<string> categoryIds,
        double radiusKm,
        int limit = 50);

    /// <summary>
    /// Searches for POIs using fuzzy search with category keywords
    /// </summary>
    Task<List<PointOfInterest>> SearchPoisFuzzyAsync(
        LocationPoint center,
        List<string> searchTerms,
        double radiusKm,
        int limit = 25);

    /// <summary>
    /// Gets detailed POI information including opening hours
    /// </summary>
    Task<PointOfInterest?> GetPoiDetailsAsync(string poiId);

    /// <summary>
    /// Checks if transit/public transport is available for the area
    /// </summary>
    Task<bool> IsTransitAvailableAsync(LocationPoint center);

    /// <summary>
    /// Gets the complete POI category tree from Azure Maps
    /// </summary>
    Task<List<PoiCategory>> GetPoiCategoryTreeAsync(string? language = null);
}

/// <summary>
/// Represents an Azure Maps access token
/// </summary>
public class AzureMapsToken
{
    public string AccessToken { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public int ExpiresInSeconds => Math.Max(0, (int)(ExpiresAt - DateTime.UtcNow).TotalSeconds);
}

/// <summary>
/// Route calculation result
/// </summary>
public class RouteResult
{
    public int DistanceMeters { get; set; }
    public int TravelTimeMinutes { get; set; }
    public List<LocationPoint> RoutePoints { get; set; } = [];
    public string? TransitInfo { get; set; }
}

/// <summary>
/// Isochrone/reachability area result
/// </summary>
public class IsochroneResult
{
    public List<LocationPoint> Boundary { get; set; } = [];
    public double CenterLatitude { get; set; }
    public double CenterLongitude { get; set; }
    public int TimeMinutes { get; set; }
    public TravelMode Mode { get; set; }
}