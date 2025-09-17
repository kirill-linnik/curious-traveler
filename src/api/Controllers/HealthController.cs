using Microsoft.AspNetCore.Mvc;

namespace CuriousTraveler.Api.Controllers;

[ApiController]
[Route("api")]
public class HealthController : ControllerBase
{
    private readonly ILogger<HealthController> _logger;

    public HealthController(ILogger<HealthController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Liveness probe - indicates if the application is running
    /// </summary>
    [HttpGet("healthz")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public IActionResult Liveness()
    {
        return Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
    }

    /// <summary>
    /// Readiness probe - indicates if the application is ready to serve traffic
    /// </summary>
    [HttpGet("readyz")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status503ServiceUnavailable)]
    public IActionResult Readiness()
    {
        // Add checks for external dependencies here
        // For now, just return healthy if the app is running
        
        try
        {
            // You could add checks for:
            // - Database connectivity
            // - External API availability
            // - Required configuration presence
            
            return Ok(new { 
                status = "ready", 
                timestamp = DateTime.UtcNow,
                checks = new { 
                    application = "healthy"
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Readiness check failed");
            return StatusCode(503, new { 
                status = "not ready", 
                timestamp = DateTime.UtcNow,
                error = ex.Message
            });
        }
    }
}