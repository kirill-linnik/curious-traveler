using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.ComponentModel.DataAnnotations;
using System.Globalization;

namespace CuriousTraveler.Api.Controllers;

[ApiController]
[Route("api/geocode")]
[EnableRateLimiting("GeocodingPolicy")]
public class GeocodingController : ControllerBase
{
    private readonly IAzureMapsService _azureMapsService;
    private readonly ILogger<GeocodingController> _logger;

    public GeocodingController(IAzureMapsService azureMapsService, ILogger<GeocodingController> logger)
    {
        _azureMapsService = azureMapsService;
        _logger = logger;
    }

    /// <summary>
    /// Reverse geocode coordinates to an address
    /// </summary>
    /// <param name="lat">Latitude coordinate (-90 to 90)</param>
    /// <param name="lon">Longitude coordinate (-180 to 180)</param>
    /// <param name="lang">Language code (optional, defaults to Accept-Language header or 'en')</param>
    /// <returns>Address information for the given coordinates</returns>
    [HttpGet("reverse")]
    [ProducesResponseType(typeof(ReverseGeocodeResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status429TooManyRequests)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> ReverseGeocode(
        [FromQuery(Name = "latitude")] double? lat,
        [FromQuery(Name = "longitude")] double? lon,
        [FromQuery] string? lang = null)
    {
        // Validate required parameters
        if (!lat.HasValue)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Missing latitude",
                Detail = "Latitude parameter is required",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        if (!lon.HasValue)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Missing longitude",
                Detail = "Longitude parameter is required",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        // Validate coordinate ranges
        if (lat.Value < -90 || lat.Value > 90)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid latitude",
                Detail = "Latitude must be between -90 and 90 degrees",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        if (lon.Value < -180 || lon.Value > 180)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid longitude",
                Detail = "Longitude must be between -180 and 180 degrees",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        var language = GetLanguage(lang);
        
        _logger.LogInformation("Reverse geocoding request for {Latitude}, {Longitude} in language {Language}", 
            lat.Value, lon.Value, language);

        try
        {
            var result = await _azureMapsService.ReverseGeocodeAsync(lat.Value, lon.Value, language);
            
            // Add cache headers
            Response.Headers.CacheControl = "public, max-age=300"; // 5 minutes
            
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error reverse geocoding for {Latitude}, {Longitude}", lat, lon);
            return StatusCode(500, new ProblemDetails
            {
                Status = 500,
                Title = "Internal Server Error",
                Detail = "An error occurred while processing the reverse geocoding request."
            });
        }
    }

    /// <summary>
    /// Handle CORS preflight requests
    /// </summary>
    /// <returns>OK result for OPTIONS requests</returns>
    [HttpOptions("reverse")]
    [HttpOptions("search")]
    public IActionResult Options()
    {
        // Add CORS headers manually for OPTIONS requests
        Response.Headers.Append("Access-Control-Allow-Origin", "*");
        Response.Headers.Append("Access-Control-Allow-Methods", "GET, OPTIONS");
        Response.Headers.Append("Access-Control-Allow-Headers", "Accept, Accept-Language, Content-Type");
        return Ok();
    }

    /// <summary>
    /// Search for locations by name or address
    /// </summary>
    /// <param name="query">Search query</param>
    /// <param name="lang">Language code (optional)</param>
    /// <param name="latitude">User's latitude for location bias (optional)</param>
    /// <param name="longitude">User's longitude for location bias (optional)</param>
    /// <param name="limit">Maximum number of results (1-20, default: 10)</param>
    /// <returns>List of matching locations</returns>
    [HttpGet("search")]
    [ProducesResponseType(typeof(List<GeocodeSearchResult>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status429TooManyRequests)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> SearchLocations(
        [FromQuery] string query,
        [FromQuery] string? lang = null,
        [FromQuery] double? latitude = null,
        [FromQuery] double? longitude = null,
        [FromQuery] int limit = 10)
    {
        // Validate query
        if (string.IsNullOrWhiteSpace(query))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Missing query parameter",
                Detail = "Query parameter 'query' is required and cannot be empty",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        if (query.Length < 2)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Query too short",
                Detail = "Query must be at least 2 characters long",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        // Validate limit
        if (limit < 1 || limit > 20)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid limit",
                Detail = "Limit must be between 1 and 20",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        // Validate user coordinates if provided
        if ((latitude.HasValue && !longitude.HasValue) || (!latitude.HasValue && longitude.HasValue))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid user location",
                Detail = "Both latitude and longitude must be provided if using location bias",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        if (latitude.HasValue && (latitude < -90 || latitude > 90))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid user latitude",
                Detail = "User latitude must be between -90 and 90 degrees",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        if (longitude.HasValue && (longitude < -180 || longitude > 180))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid user longitude",
                Detail = "User longitude must be between -180 and 180 degrees",
                Status = 400,
                Instance = HttpContext?.Request?.Path
            });
        }

        var language = GetLanguage(lang);
        
        _logger.LogInformation("Geocoding search request for '{Query}' in language {Language} with limit {Limit}", 
            query, language, limit);

        try
        {
            var results = await _azureMapsService.SearchAsync(query, language, latitude, longitude, limit);
            
            // Add cache headers
            Response.Headers.CacheControl = "public, max-age=60"; // 1 minute
            
            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching for '{Query}'", query);
            return StatusCode(500, new ProblemDetails
            {
                Status = 500,
                Title = "Internal Server Error",
                Detail = "An error occurred while processing the search request."
            });
        }
    }

    private string GetLanguage(string? requestedLanguage)
    {
        if (!string.IsNullOrWhiteSpace(requestedLanguage))
        {
            return requestedLanguage;
        }

        // Try to get language from Accept-Language header
        try
        {
            var acceptLanguage = Request?.Headers?.AcceptLanguage.FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(acceptLanguage))
            {
                var culture = CultureInfo.GetCultureInfo(acceptLanguage.Split(',')[0].Split(';')[0].Trim());
                return culture.TwoLetterISOLanguageName;
            }
        }
        catch
        {
            // Fall back to default if parsing fails or Request/Headers is null
        }

        return "en"; // Default language
    }
}