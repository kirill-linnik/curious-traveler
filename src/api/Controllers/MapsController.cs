using CuriousTraveler.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CuriousTraveler.Api.Controllers;

[ApiController]
[Route("api/maps")]
[EnableRateLimiting("MapsPolicy")]
public class MapsController : ControllerBase
{
    private readonly IAzureMapsService _azureMapsService;
    private readonly ILogger<MapsController> _logger;
    private readonly IConfiguration _configuration;

    public MapsController(
        IAzureMapsService azureMapsService, 
        ILogger<MapsController> logger,
        IConfiguration configuration)
    {
        _azureMapsService = azureMapsService;
        _logger = logger;
        _configuration = configuration;
    }

    /// <summary>
    /// Gets an access token for Azure Maps client-side authentication
    /// Available only in AAD authentication mode
    /// </summary>
    /// <returns>Azure Maps access token with expiration information</returns>
    [HttpGet("token")]
    [ProducesResponseType(typeof(MapsTokenResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status429TooManyRequests)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public IActionResult GetAccessToken()
    {
        // Access tokens are not needed with subscription key authentication
        _logger.LogWarning("Access token requested but only subscription key authentication is supported");
        return BadRequest(new ProblemDetails
        {
            Title = "Access tokens not available",
            Detail = "This application uses subscription key authentication. Access tokens are not needed or supported.",
            Status = 400,
            Instance = HttpContext.Request.Path
        });
    }

    /// <summary>
    /// Proxy endpoint for Azure Maps tile requests (KEY mode only)
    /// This endpoint fetches map tiles server-side to avoid exposing subscription keys to clients
    /// </summary>
    /// <param name="tilePath">The tile path including coordinates and style</param>
    /// <returns>The map tile data</returns>
    [HttpGet("tiles/{**tilePath}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public IActionResult GetTileProxy(string tilePath)
    {
        // Tile proxy not implemented for subscription key authentication
        _logger.LogWarning("Tile proxy requested but not implemented for subscription key authentication");
        return StatusCode(501, new ProblemDetails
        {
            Title = "Not implemented",
            Detail = "Tile proxy is not supported. Use AAD authentication with Azure Maps client-side integration instead.",
            Status = 501,
            Instance = HttpContext.Request.Path
        });
    }
}

/// <summary>
/// Response model for Azure Maps access token
/// </summary>
public class MapsTokenResponse
{
    /// <summary>
    /// The access token for Azure Maps
    /// </summary>
    public string AccessToken { get; set; } = string.Empty;

    /// <summary>
    /// Token expiration time in seconds
    /// </summary>
    public int ExpiresIn { get; set; }

    /// <summary>
    /// Token type (always "Bearer")
    /// </summary>
    public string TokenType { get; set; } = "Bearer";
}