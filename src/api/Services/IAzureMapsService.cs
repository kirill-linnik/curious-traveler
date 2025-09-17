using CuriousTraveler.Api.Models;

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