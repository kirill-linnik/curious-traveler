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
            Detail = "Tile proxy is not supported with subscription key authentication.",
            Status = 501,
            Instance = HttpContext.Request.Path
        });
    }
}