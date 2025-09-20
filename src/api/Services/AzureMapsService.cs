using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Models.AzureMaps;
using CuriousTraveler.Api.Models.Itinerary;
using Microsoft.Extensions.Caching.Memory;
using System.Text.Json;
using System.Text.Json.Serialization;

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

        _accountName = _configuration["AzureMaps:AccountName"] ?? 
                      throw new InvalidOperationException("AzureMaps:AccountName configuration is required");
        
        // Get subscription key for authentication
        _subscriptionKey = _configuration["AzureMaps:SubscriptionKey"];

        if (string.IsNullOrWhiteSpace(_subscriptionKey))
        {
            throw new InvalidOperationException("AzureMaps:SubscriptionKey configuration is required");
        }

        _logger.LogInformation("Azure Maps Service initialized with subscription key authentication for account: {AccountName}", _accountName);
    }

    /// <summary>
    /// Helper method to build Azure Maps API URLs with proper authentication
    /// </summary>
    private string BuildUrl(string endpoint, Dictionary<string, string>? parameters = null)
    {
        var url = $"{AzureMapsBaseUrl}{endpoint}";
        var queryParams = new List<string>();
        
        if (parameters != null)
        {
            foreach (var param in parameters)
            {
                queryParams.Add($"{param.Key}={Uri.EscapeDataString(param.Value)}");
            }
        }
        
        // Add authentication based on mode
        if (!string.IsNullOrWhiteSpace(_subscriptionKey))
        {
            queryParams.Add($"subscription-key={_subscriptionKey}");
        }
        
        if (queryParams.Any())
        {
            url += "?" + string.Join("&", queryParams);
        }
        
        return url;
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

    /// <summary>
    /// Gets the local timezone for coordinates
    /// </summary>
    public async Task<TimeZoneInfo> GetTimeZoneAsync(double latitude, double longitude)
    {
        var cacheKey = $"timezone_{latitude:F6}_{longitude:F6}";
        
        if (_cache.TryGetValue(cacheKey, out TimeZoneInfo? cachedTimeZone) && cachedTimeZone != null)
        {
            return cachedTimeZone;
        }

        try
        {
            var url = $"{AzureMapsBaseUrl}/timezone/byCoordinates/json?api-version=1.0&subscription-key={_subscriptionKey}&query={latitude},{longitude}";
            
            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            var timezoneResponse = JsonSerializer.Deserialize<AzureMapsTimezoneResponse>(jsonResponse);
            
            var timezoneId = timezoneResponse?.TimeZones?.FirstOrDefault()?.Id ?? "UTC";
            var timeZone = TimeZoneInfo.FindSystemTimeZoneById(timezoneId);
            
            _cache.Set(cacheKey, timeZone, TimeSpan.FromHours(24));
            
            return timeZone;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get timezone for {Lat},{Lon}, defaulting to UTC", latitude, longitude);
            return TimeZoneInfo.Utc;
        }
    }

    /// <summary>
    /// Calculates route between two points
    /// </summary>
    public async Task<RouteResult> GetRouteAsync(LocationPoint start, LocationPoint end, TravelMode mode)
    {
        // Handle identical coordinates - return a zero-distance route
        if (Math.Abs(start.Lat - end.Lat) < 0.0001 && Math.Abs(start.Lon - end.Lon) < 0.0001)
        {
            return new RouteResult
            {
                DistanceMeters = 0,
                TravelTimeMinutes = 0,
                RoutePoints = new List<LocationPoint> { start }
            };
        }

        try
        {
            var travelMode = mode switch
            {
                TravelMode.Walking => "pedestrian",
                TravelMode.Car => "car",
                TravelMode.PublicTransport => "publicTransit",
                _ => "pedestrian"
            };

            var url = $"{AzureMapsBaseUrl}/route/directions/json?api-version=1.0&subscription-key={_subscriptionKey}" +
                     $"&query={start.Lat},{start.Lon}:{end.Lat},{end.Lon}&travelMode={travelMode}";

            if (mode == TravelMode.PublicTransport)
            {
                url += "&transitType=bus,subway,tram,rail";
            }

            _logger.LogDebug("DEBUG: Route request - URL: {Url}", _subscriptionKey != null ? url.Replace(_subscriptionKey, "***") : url);
            _logger.LogDebug("DEBUG: Route request - From: ({StartLat},{StartLon}) To: ({EndLat},{EndLon}), Mode: {Mode}", 
                start.Lat, start.Lon, end.Lat, end.Lon, mode);

            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            _logger.LogDebug("DEBUG: Route response length: {Length} chars", jsonResponse.Length);
            
            var routeResponse = JsonSerializer.Deserialize<AzureMapsRouteResponse>(jsonResponse);
            _logger.LogDebug("DEBUG: Deserialized route response - Routes count: {RoutesCount}", 
                routeResponse?.Routes?.Count ?? 0);
            
            var route = routeResponse?.Routes?.FirstOrDefault();
            if (route == null)
            {
                _logger.LogWarning("Azure Maps returned no routes. Response: {Response}", jsonResponse);
                
                // Calculate straight-line distance as fallback
                var distance = CalculateDistance(start.Lat, start.Lon, end.Lat, end.Lon);
                _logger.LogDebug("DEBUG: Using straight-line fallback - Distance: {Distance}m", distance);
                
                return new RouteResult
                {
                    DistanceMeters = (int)distance,
                    TravelTimeMinutes = mode switch
                    {
                        TravelMode.Walking => (int)(distance / 80), // ~5 km/h walking speed
                        TravelMode.Car => (int)(distance / 500), // ~30 km/h city driving
                        TravelMode.PublicTransport => (int)(distance / 300), // ~18 km/h transit
                        _ => (int)(distance / 80)
                    },
                    RoutePoints = new List<LocationPoint> { start, end }
                };
            }

            _logger.LogDebug("DEBUG: Using Azure Maps route - Distance: {Distance}m, Time: {Time}s", 
                route.Summary?.LengthInMeters ?? 0, route.Summary?.TravelTimeInSeconds ?? 0);

            return new RouteResult
            {
                DistanceMeters = route.Summary?.LengthInMeters ?? 0,
                TravelTimeMinutes = (route.Summary?.TravelTimeInSeconds ?? 0) / 60,
                RoutePoints = route.Legs?.SelectMany(l => l.Points ?? [])
                    .Select(p => new LocationPoint { Lat = p.Latitude, Lon = p.Longitude })
                    .ToList() ?? []
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get route from {StartLat},{StartLon} to {EndLat},{EndLon}", 
                start.Lat, start.Lon, end.Lat, end.Lon);
            throw;
        }
    }

    /// <summary>
    /// Gets isochrone/reachability area from a point
    /// </summary>
    public async Task<IsochroneResult?> GetIsochroneAsync(LocationPoint center, TravelMode mode, int timeMinutes)
    {
        _logger.LogDebug("DEBUG: Isochrone request - Center: ({Lat},{Lon}), Mode: {Mode}, Time: {Time} min", 
            center.Lat, center.Lon, mode, timeMinutes);
            
        try
        {
            var travelMode = mode switch
            {
                TravelMode.Walking => "pedestrian",
                TravelMode.Car => "car", 
                TravelMode.PublicTransport => "publicTransit",
                _ => "pedestrian"
            };

            var url = $"{AzureMapsBaseUrl}/route/range/json?api-version=1.0&subscription-key={(_subscriptionKey?.Length > 10 ? _subscriptionKey[..10] + "***" : "***")}" +
                     $"&query={center.Lat},{center.Lon}&timeBudgetInSec={timeMinutes * 60}&travelMode={travelMode}";
            
            _logger.LogDebug("DEBUG: Isochrone URL: {Url}", url.Replace(_subscriptionKey ?? "", "***"));

            var response = await _httpClient.GetAsync(url);
            
            _logger.LogDebug("DEBUG: Isochrone response status: {StatusCode}", response.StatusCode);
            
            // If isochrone API is not available, return null to trigger fallback
            if (response.StatusCode == System.Net.HttpStatusCode.BadRequest || 
                response.StatusCode == System.Net.HttpStatusCode.NotImplemented)
            {
                _logger.LogInformation("Isochrone not available for mode {Mode}, will use radius fallback", mode);
                return null;
            }

            response.EnsureSuccessStatusCode();
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            var isochroneResponse = JsonSerializer.Deserialize<AzureMapsIsochroneResponse>(jsonResponse);
            
            var boundary = isochroneResponse?.ReachableRange?.Boundary?.Select(p => 
                new LocationPoint { Lat = p.Latitude, Lon = p.Longitude }).ToList() ?? [];

            _logger.LogDebug("DEBUG: Isochrone success - Boundary points: {Count}", boundary.Count);

            return new IsochroneResult
            {
                Boundary = boundary,
                CenterLatitude = center.Lat,
                CenterLongitude = center.Lon,
                TimeMinutes = timeMinutes,
                Mode = mode
            };
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get isochrone for {Lat},{Lon}, mode {Mode}", 
                center.Lat, center.Lon, mode);
            return null;
        }
    }

    /// <summary>
    /// Searches for POIs by category within a geographic area
    /// </summary>
    public async Task<List<PointOfInterest>> SearchPoisAsync(
        LocationPoint center,
        List<int> categoryIds,
        double radiusKm,
        int limit = 10)
    {
        try
        {
            var radiusMeters = (int)(radiusKm * 1000);
            
            if (!categoryIds.Any())
            {
                _logger.LogWarning("No category IDs provided for POI search");
                return [];
            }
            
            // Combine all category IDs into a single request as recommended by Azure Maps documentation
            var categorySet = string.Join(",", categoryIds);
            
            // Use the correct Azure Maps POI search endpoint with categorySet parameter
            // Azure Maps requires a query parameter, use a generic term that works with category filtering
            var url = $"{AzureMapsBaseUrl}/search/poi/json?api-version=1.0&subscription-key={_subscriptionKey}" +
                     $"&query=*&categorySet={categorySet}&lat={center.Lat}&lon={center.Lon}&radius={radiusMeters}&limit={limit}&openingHours=nextSevenDays";

            _logger.LogDebug("DEBUG: POI Search - URL: {Url}", _subscriptionKey != null ? url.Replace(_subscriptionKey, "***") : url);
            _logger.LogDebug("DEBUG: POI Search - Center: ({Lat},{Lon}), Radius: {RadiusKm}km, Categories: {CategorySet}, Limit: {Limit}", 
                center.Lat, center.Lon, radiusKm, categorySet, limit);

            var response = await _httpClient.GetAsync(url);
            
            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError("Azure Maps POI search failed with status {StatusCode}: {ErrorContent}", 
                    response.StatusCode, errorContent);
                response.EnsureSuccessStatusCode(); // This will throw with the status code
            }
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            _logger.LogDebug("DEBUG: POI Search - Response length: {Length} chars", jsonResponse.Length);
            
            var searchResponse = JsonSerializer.Deserialize<AzureMapsSearchResponse>(jsonResponse);
            var resultCount = searchResponse?.Results?.Count ?? 0;
            _logger.LogDebug("DEBUG: POI Search - Found {Count} raw results (requested {Limit})", 
                resultCount, limit);
            
            var allPois = new List<PointOfInterest>();
            foreach (var result in searchResponse?.Results ?? [])
            {
                if (result.Position == null || result.Poi?.Name == null) continue;
                
                var poi = new PointOfInterest
                {
                    Id = $"maps_{result.Position.Lat:F6}_{result.Position.Lon:F6}",
                    Name = result.Poi.Name,
                    Address = result.Address?.FreeformAddress ?? "",
                    Latitude = result.Position.Lat,
                    Longitude = result.Position.Lon,
                    Category = result.Poi.Categories?.FirstOrDefault(),
                    Tags = result.Poi.Categories?.ToList() ?? [],
                    DistanceFromStartMeters = (int)CalculateDistance(center.Lat, center.Lon, result.Position.Lat, result.Position.Lon)
                };
                
                allPois.Add(poi);
            }
            
            // Sort by distance for consistent ordering
            var finalPois = allPois
                .OrderBy(p => p.DistanceFromStartMeters)
                .ToList();
            
            _logger.LogDebug("DEBUG: POI Search - Returning {Count} total POIs from combined categories", 
                finalPois.Count);
            return finalPois;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to search POIs near {Lat},{Lon}", center.Lat, center.Lon);
            return [];
        }
    }

    public async Task<List<PointOfInterest>> SearchPoisFuzzyAsync(
        LocationPoint center,
        List<string> searchTerms,
        double radiusKm,
        int limit = 25)
    {
        try
        {
            var query = string.Join(" ", searchTerms);
            var radiusMeters = (int)(radiusKm * 1000);
            
            var url = $"{AzureMapsBaseUrl}/search/fuzzy/json?api-version=1.0&subscription-key={_subscriptionKey}" +
                     $"&query={Uri.EscapeDataString(query)}&lat={center.Lat}&lon={center.Lon}&radius={radiusMeters}&limit={limit}" +
                     $"&idxSet=POI&sortBy=distance&view=Unified";

            _logger.LogDebug("DEBUG: Fuzzy POI Search - URL: {Url}", _subscriptionKey != null ? url.Replace(_subscriptionKey, "***") : url);
            _logger.LogDebug("DEBUG: Fuzzy POI Search - Center: ({Lat},{Lon}), Radius: {RadiusKm}km, Query: {Query}", 
                center.Lat, center.Lon, radiusKm, query);

            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            _logger.LogDebug("DEBUG: Fuzzy POI Search - Response length: {Length} chars", jsonResponse.Length);
            _logger.LogDebug("DEBUG: Fuzzy POI Search - Raw response: {Response}", jsonResponse);

            var searchResponse = JsonSerializer.Deserialize<AzureMapsSearchResponse>(jsonResponse);
            _logger.LogDebug("DEBUG: Fuzzy POI Search - Found {Count} raw results", searchResponse?.Results?.Count ?? 0);

            var pois = new List<PointOfInterest>();

            foreach (var result in searchResponse?.Results ?? [])
            {
                if (result.Position == null || result.Poi?.Name == null) continue;

                // Calculate a relevance score based on Azure Maps score and additional factors
                double relevanceScore = result.Score ?? 1.0;
                
                // Boost score for POIs with more complete information
                if (!string.IsNullOrEmpty(result.Poi.Phone)) relevanceScore += 0.2;
                if (!string.IsNullOrEmpty(result.Poi.Url)) relevanceScore += 0.1;
                if (result.Poi.Brands?.Any() == true) relevanceScore += 0.15; // Brand recognition
                if (result.Poi.CategorySet?.Any() == true) relevanceScore += 0.1;
                if (result.Poi.Categories?.Count > 1) relevanceScore += 0.1;
                
                // Boost score for certain high-quality name indicators
                var name = result.Poi.Name.ToLowerInvariant();
                if (name.Contains("restaurant") || name.Contains("cafe") || name.Contains("hotel") || 
                    name.Contains("museum") || name.Contains("church") || name.Contains("park")) relevanceScore += 0.2;

                var poi = new PointOfInterest
                {
                    Id = $"fuzzy_{Guid.NewGuid():N}",
                    Name = result.Poi.Name,
                    Latitude = result.Position.Lat,
                    Longitude = result.Position.Lon,
                    Address = result.Address?.FreeformAddress ?? "",
                    Category = result.Poi.Categories?.FirstOrDefault() ?? "Unknown",
                    Description = result.Poi.Categories?.FirstOrDefault() ?? "",
                    Rating = relevanceScore, // Use enhanced relevance score
                    EstimatedMinVisitMinutes = 30
                };

                pois.Add(poi);
            }

            // Sort by our calculated relevance score (stored in Rating field)
            pois = pois.OrderByDescending(p => p.Rating).ToList();

            _logger.LogDebug("DEBUG: Fuzzy POI Search - Returning {Count} valid POIs", pois.Count);
            return pois;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to search POIs using fuzzy search at {Lat},{Lon}", center.Lat, center.Lon);
            return new List<PointOfInterest>();
        }
    }

    /// <summary>
    /// Gets detailed POI information including opening hours
    /// </summary>
    public async Task<PointOfInterest?> GetPoiDetailsAsync(string poiId)
    {
        // For this implementation, detailed POI info is fetched during search
        // In a full implementation, this would call a POI details API
        await Task.CompletedTask;
        return null;
    }

    /// <summary>
    /// Checks if transit/public transport is available for the area
    /// </summary>
    public async Task<bool> IsTransitAvailableAsync(LocationPoint center)
    {
        try
        {
            // Try to get a short transit route to test availability
            var nearbyPoint = new LocationPoint 
            { 
                Lat = center.Lat + 0.01, 
                Lon = center.Lon + 0.01 
            };
            
            var url = $"{AzureMapsBaseUrl}/route/directions/json?api-version=1.0&subscription-key={_subscriptionKey}" +
                     $"&query={center.Lat},{center.Lon}:{nearbyPoint.Lat},{nearbyPoint.Lon}&travelMode=publicTransit";

            var response = await _httpClient.GetAsync(url);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<List<PoiCategory>> GetPoiCategoryTreeAsync(string? language = null)
    {
        var cacheKey = $"poi_categories_{language ?? "en"}";
        
        // Try cache first - categories don't change often, cache for 24 hours
        if (_cache.TryGetValue(cacheKey, out List<PoiCategory>? cachedCategories))
        {
            return cachedCategories ?? new List<PoiCategory>();
        }

        try
        {
            var url = $"{AzureMapsBaseUrl}/search/poi/category/tree/json?api-version=1.0&subscription-key={_subscriptionKey}";
            
            if (!string.IsNullOrEmpty(language))
            {
                url += $"&language={language}";
            }

            _logger.LogDebug("Fetching POI category tree from Azure Maps");
            
            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
            
            var jsonResponse = await response.Content.ReadAsStringAsync();
            var categoryTreeResponse = JsonSerializer.Deserialize<PoiCategoryTreeResponse>(jsonResponse);
            
            var categories = categoryTreeResponse?.PoiCategories ?? new List<PoiCategory>();
            
            // Cache for 24 hours
            _cache.Set(cacheKey, categories, TimeSpan.FromHours(24));
            
            _logger.LogInformation("Loaded {Count} POI categories from Azure Maps", categories.Count);
            
            return categories;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to fetch POI category tree from Azure Maps");
            return new List<PoiCategory>();
        }
    }

    private static double CalculateDistance(double lat1, double lon1, double lat2, double lon2)
    {
        // Haversine formula for distance calculation
        const double R = 6371000; // Earth's radius in meters
        var dLat = DegreesToRadians(lat2 - lat1);
        var dLon = DegreesToRadians(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(DegreesToRadians(lat1)) * Math.Cos(DegreesToRadians(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return R * c;
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;
}

// Azure Maps API response models
public class AzureMapsReverseGeocodeResponse
{
    public List<AzureMapsAddress>? Addresses { get; set; }
}

public class AzureMapsAddress
{
    [JsonPropertyName("address")]
    public AzureMapsAddressInfo? Address { get; set; }
}

public class AzureMapsAddressInfo
{
    [JsonPropertyName("freeformAddress")]
    public string? FreeformAddress { get; set; }
    
    [JsonPropertyName("municipality")]
    public string? Municipality { get; set; }
    
    [JsonPropertyName("country")]
    public string? Country { get; set; }
    
    [JsonPropertyName("countryCode")]
    public string? CountryCode { get; set; }
    
    [JsonPropertyName("postalCode")]
    public string? PostalCode { get; set; }
    
    [JsonPropertyName("streetName")]
    public string? StreetName { get; set; }
    
    [JsonPropertyName("streetNumber")]
    public string? StreetNumber { get; set; }
}

public class AzureMapsSearchResponse
{
    [JsonPropertyName("results")]
    public List<AzureMapsSearchResult>? Results { get; set; }
}

public class AzureMapsSearchResult
{
    [JsonPropertyName("type")]
    public string? Type { get; set; }
    [JsonPropertyName("id")]
    public string? Id { get; set; }
    [JsonPropertyName("score")]
    public double? Score { get; set; }
    [JsonPropertyName("dist")]
    public double? Distance { get; set; }
    [JsonPropertyName("info")]
    public string? Info { get; set; }
    [JsonPropertyName("address")]
    public AzureMapsAddressInfo? Address { get; set; }
    [JsonPropertyName("position")]
    public AzureMapsPosition? Position { get; set; }
    [JsonPropertyName("poi")]
    public AzureMapsPoi? Poi { get; set; }
}

public class AzureMapsPosition
{
    [JsonPropertyName("lat")]
    public double Lat { get; set; }
    [JsonPropertyName("lon")]
    public double Lon { get; set; }
}

public class AzureMapsPoi
{
    [JsonPropertyName("name")]
    public string? Name { get; set; }
    [JsonPropertyName("phone")]
    public string? Phone { get; set; }
    [JsonPropertyName("categorySet")]
    public List<AzureMapsCategory>? CategorySet { get; set; }
    [JsonPropertyName("categories")]
    public List<string>? Categories { get; set; }
    [JsonPropertyName("classifications")]
    public List<AzureMapsClassification>? Classifications { get; set; }
    [JsonPropertyName("url")]
    public string? Url { get; set; }
    [JsonPropertyName("brands")]
    public List<AzureMapsBrand>? Brands { get; set; }
}

public class AzureMapsCategory
{
    [JsonPropertyName("id")]
    public int Id { get; set; }
}

public class AzureMapsClassification
{
    [JsonPropertyName("code")]
    public string? Code { get; set; }
    [JsonPropertyName("names")]
    public List<AzureMapsName>? Names { get; set; }
}

public class AzureMapsName
{
    [JsonPropertyName("nameLocale")]
    public string? NameLocale { get; set; }
    [JsonPropertyName("name")]
    public string? Name { get; set; }
}

public class AzureMapsBrand
{
    [JsonPropertyName("name")]
    public string? Name { get; set; }
}

// Additional response models for new functionality

public class AzureMapsTimezoneResponse
{
    public List<AzureMapsTimezone>? TimeZones { get; set; }
}

public class AzureMapsTimezone
{
    public string? Id { get; set; }
}

public class AzureMapsRouteResponse
{
    [JsonPropertyName("routes")]
    public List<AzureMapsRoute>? Routes { get; set; }
}

public class AzureMapsRoute
{
    [JsonPropertyName("summary")]
    public AzureMapsRouteSummary? Summary { get; set; }
    
    [JsonPropertyName("legs")]
    public List<AzureMapsRouteLeg>? Legs { get; set; }
}

public class AzureMapsRouteSummary
{
    [JsonPropertyName("lengthInMeters")]
    public int LengthInMeters { get; set; }
    
    [JsonPropertyName("travelTimeInSeconds")]
    public int TravelTimeInSeconds { get; set; }
}

public class AzureMapsRouteLeg
{
    [JsonPropertyName("points")]
    public List<AzureMapsRoutePoint>? Points { get; set; }
}

public class AzureMapsRoutePoint
{
    [JsonPropertyName("latitude")]
    public double Latitude { get; set; }
    
    [JsonPropertyName("longitude")]
    public double Longitude { get; set; }
}

public class AzureMapsIsochroneResponse
{
    public AzureMapsReachableRange? ReachableRange { get; set; }
}

public class AzureMapsReachableRange
{
    public List<AzureMapsRoutePoint>? Boundary { get; set; }
}
