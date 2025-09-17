using CuriousTraveler.Api.Models;
using Microsoft.Extensions.Caching.Memory;
using System.Text.Json;

namespace CuriousTraveler.Api.Services;

/// <summary>
/// Azure Maps service implementation with subscription key authentication
/// </summary>
public class AzureMapsService : IAzureMapsService
{
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger<AzureMapsService> _logger;
    private readonly IConfiguration _configuration;
    private readonly string _accountName;
    private readonly string? _subscriptionKey;

    private const string AzureMapsBaseUrl = "https://atlas.microsoft.com";

    public AzureMapsService(
        HttpClient httpClient,
        IMemoryCache cache,
        ILogger<AzureMapsService> logger,
        IConfiguration configuration)
    {
        _httpClient = httpClient;
        _cache = cache;
        _logger = logger;
        _configuration = configuration;

        _accountName = _configuration["AZURE_MAPS_ACCOUNT_NAME"] ?? 
                      throw new InvalidOperationException("AZURE_MAPS_ACCOUNT_NAME configuration is required");
        
        // Get subscription key for authentication
        _subscriptionKey = _configuration["AZURE_MAPS_SUBSCRIPTION_KEY"];

        if (string.IsNullOrWhiteSpace(_subscriptionKey))
        {
            throw new InvalidOperationException("AZURE_MAPS_SUBSCRIPTION_KEY configuration is required");
        }

        _logger.LogInformation("Azure Maps Service initialized with subscription key authentication for account: {AccountName}", _accountName);
    }

    /// <summary>
    /// Performs reverse geocoding to get address from coordinates
    /// </summary>
    public async Task<ReverseGeocodeResponse> ReverseGeocodeAsync(double latitude, double longitude, string? language = null)
    {
        try
        {
            _logger.LogInformation("Starting reverse geocoding for coordinates: {Latitude}, {Longitude}", latitude, longitude);

            var lang = language ?? "en-US";
            var cacheKey = $"reverse_{latitude:F6}_{longitude:F6}_{lang}";
            if (_cache.TryGetValue(cacheKey, out ReverseGeocodeResponse? cachedResult) && cachedResult != null)
            {
                _logger.LogDebug("Returning cached reverse geocoding result for {Latitude}, {Longitude}", latitude, longitude);
                return cachedResult;
            }

            var url = $"{AzureMapsBaseUrl}/search/address/reverse/json?api-version=1.0&query={latitude},{longitude}&language={lang}&subscription-key={_subscriptionKey}";
            
            _logger.LogDebug("Making reverse geocoding request to: {Url}", url.Replace(_subscriptionKey!, "[REDACTED]"));

            var response = await _httpClient.GetAsync(url);
            var content = await response.Content.ReadAsStringAsync();

            _logger.LogDebug("Azure Maps API response status: {StatusCode}", response.StatusCode);
            _logger.LogDebug("Azure Maps API response content: {Content}", content);

            response.EnsureSuccessStatusCode();

            var azureResponse = JsonSerializer.Deserialize<AzureMapsReverseGeocodeResponse>(content, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var result = new ReverseGeocodeResponse();

            if (azureResponse?.Addresses != null && azureResponse.Addresses.Any())
            {
                var address = azureResponse.Addresses.First().Address;
                result.FormattedAddress = address?.FreeformAddress ?? "Address not available";
                result.Locality = address?.Municipality ?? "";
                result.CountryCode = address?.CountryCode ?? "";
                result.Center = new GeocodePosition
                {
                    Latitude = latitude,
                    Longitude = longitude
                };
            }
            else
            {
                _logger.LogWarning("No addresses found in Azure Maps response for coordinates {Latitude}, {Longitude}", latitude, longitude);
                result.FormattedAddress = "Address not available";
                result.Center = new GeocodePosition
                {
                    Latitude = latitude,
                    Longitude = longitude
                };
            }

            // Cache the result for 1 hour
            _cache.Set(cacheKey, result, TimeSpan.FromHours(1));

            _logger.LogInformation("Successfully completed reverse geocoding for {Latitude}, {Longitude}. Result: {FormattedAddress}", 
                latitude, longitude, result.FormattedAddress);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing reverse geocoding for coordinates {Latitude}, {Longitude}", latitude, longitude);
            return new ReverseGeocodeResponse
            {
                FormattedAddress = "Error retrieving address",
                Center = new GeocodePosition { Latitude = latitude, Longitude = longitude }
            };
        }
    }

    /// <summary>
    /// Searches for places based on query string
    /// </summary>
    public async Task<List<GeocodeSearchResult>> SearchAsync(string query, string? language = null, double? userLatitude = null, double? userLongitude = null, int limit = 10)
    {
        try
        {
            _logger.LogInformation("Starting search for query: {Query}", query);

            if (string.IsNullOrWhiteSpace(query))
            {
                return new List<GeocodeSearchResult>();
            }

            var lang = language ?? "en-US";
            var cacheKey = $"search_{query}_{lang}_{userLatitude:F6}_{userLongitude:F6}_{limit}";
            if (_cache.TryGetValue(cacheKey, out List<GeocodeSearchResult>? cachedResult) && cachedResult != null)
            {
                _logger.LogDebug("Returning cached search result for query: {Query}", query);
                return cachedResult;
            }

            var url = $"{AzureMapsBaseUrl}/search/fuzzy/json?api-version=1.0&query={Uri.EscapeDataString(query)}&limit={limit}&language={lang}&subscription-key={_subscriptionKey}";
            
            if (userLatitude.HasValue && userLongitude.HasValue)
            {
                url += $"&lat={userLatitude.Value}&lon={userLongitude.Value}";
            }

            _logger.LogDebug("Making search request to: {Url}", url.Replace(_subscriptionKey!, "[REDACTED]"));

            var response = await _httpClient.GetAsync(url);
            var content = await response.Content.ReadAsStringAsync();

            _logger.LogDebug("Azure Maps API response status: {StatusCode}", response.StatusCode);
            _logger.LogDebug("Azure Maps API response content: {Content}", content);

            response.EnsureSuccessStatusCode();

            var azureResponse = JsonSerializer.Deserialize<AzureMapsSearchResponse>(content, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var results = new List<GeocodeSearchResult>();

            if (azureResponse?.Results != null)
            {
                results = azureResponse.Results.Select((r, index) => new GeocodeSearchResult
                {
                    Id = $"result_{index}",
                    Type = r.Poi?.Name != null ? "POI" : "Address",
                    Name = r.Poi?.Name ?? r.Address?.FreeformAddress ?? "Unknown",
                    FormattedAddress = r.Address?.FreeformAddress ?? "Address not available",
                    Locality = r.Address?.Municipality ?? "",
                    CountryCode = r.Address?.CountryCode ?? "",
                    Position = new GeocodePosition
                    {
                        Latitude = r.Position?.Lat ?? 0,
                        Longitude = r.Position?.Lon ?? 0
                    },
                    Confidence = "High" // Azure Maps doesn't provide confidence, so we default to High
                }).ToList();
            }

            // Cache the result for 30 minutes
            _cache.Set(cacheKey, results, TimeSpan.FromMinutes(30));

            _logger.LogInformation("Successfully completed search for query: {Query}. Found {Count} results", query, results.Count);

            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing search for query: {Query}", query);
            return new List<GeocodeSearchResult>();
        }
    }

    /// <summary>
    /// Gets an access token for Azure Maps (not used with subscription key auth)
    /// </summary>
    public async Task<AzureMapsToken> GetAccessTokenAsync()
    {
        // Not needed for subscription key authentication, return empty token
        await Task.CompletedTask;
        return new AzureMapsToken
        {
            AccessToken = "",
            ExpiresAt = DateTime.UtcNow.AddYears(1)
        };
    }
}

// Azure Maps API response models
public class AzureMapsReverseGeocodeResponse
{
    public List<AzureMapsAddress>? Addresses { get; set; }
}

public class AzureMapsAddress
{
    public AzureMapsAddressInfo? Address { get; set; }
}

public class AzureMapsAddressInfo
{
    public string? FreeformAddress { get; set; }
    public string? Municipality { get; set; }
    public string? Country { get; set; }
    public string? CountryCode { get; set; }
    public string? PostalCode { get; set; }
    public string? StreetName { get; set; }
    public string? StreetNumber { get; set; }
}

public class AzureMapsSearchResponse
{
    public List<AzureMapsSearchResult>? Results { get; set; }
}

public class AzureMapsSearchResult
{
    public AzureMapsAddressInfo? Address { get; set; }
    public AzureMapsPosition? Position { get; set; }
    public AzureMapsPoi? Poi { get; set; }
}

public class AzureMapsPosition
{
    public double Lat { get; set; }
    public double Lon { get; set; }
}

public class AzureMapsPoi
{
    public string? Name { get; set; }
    public List<string>? Categories { get; set; }
}
