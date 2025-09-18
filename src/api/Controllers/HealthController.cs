using Microsoft.AspNetCore.Mvc;
using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Services.Storage;
using CuriousTraveler.Api.Services.AI;

namespace CuriousTraveler.Api.Controllers;

[ApiController]
[Route("")]
public class HealthController : ControllerBase
{
    private readonly ILogger<HealthController> _logger;
    private readonly IAzureMapsService _mapsService;
    private readonly ITableStorageService _tableService;
    private readonly IQueueService _queueService;
    private readonly IOpenAIService _openAIService;

    public HealthController(
        ILogger<HealthController> logger,
        IAzureMapsService mapsService,
        ITableStorageService tableService,
        IQueueService queueService,
        IOpenAIService openAIService)
    {
        _logger = logger;
        _mapsService = mapsService;
        _tableService = tableService;
        _queueService = queueService;
        _openAIService = openAIService;
    }

    /// <summary>
    /// Liveness probe - indicates if the application is running
    /// </summary>
    [HttpGet("health")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public IActionResult Liveness()
    {
        return Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
    }

    /// <summary>
    /// Readiness probe - indicates if the application is ready to serve traffic
    /// </summary>
    [HttpGet("ready")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Readiness()
    {
        var checks = new Dictionary<string, object>
        {
            ["application"] = "healthy"
        };

        var isHealthy = true;

        try
        {
            // Check Azure Maps connectivity
            try
            {
                await _mapsService.GetTimeZoneAsync(59.4, 24.66); // Test with Estonia coordinates
                checks["azureMaps"] = "healthy";
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Azure Maps connectivity check failed");
                checks["azureMaps"] = "unhealthy";
                isHealthy = false;
            }

            // Check Table Storage connectivity
            try
            {
                await _tableService.GetJobAsync("health-check-test");
                checks["tableStorage"] = "healthy";
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Table Storage connectivity check failed");
                checks["tableStorage"] = "unhealthy";
                isHealthy = false;
            }

            // Check Queue Storage connectivity  
            try
            {
                var isQueueHealthy = await _queueService.IsHealthyAsync();
                if (isQueueHealthy)
                {
                    checks["queueStorage"] = "healthy";
                }
                else
                {
                    checks["queueStorage"] = "unhealthy";
                    isHealthy = false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Queue Storage connectivity check failed");
                checks["queueStorage"] = "unhealthy";
                isHealthy = false;
            }

            // Check Azure OpenAI connectivity
            try
            {
                // Simple test to verify OpenAI service is accessible
                await _openAIService.MapInterestsToCategoriesAsync(
                    "test",
                    "en", 
                    "Test City",
                    [],
                    CancellationToken.None);
                checks["azureOpenAI"] = "healthy";
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Azure OpenAI connectivity check failed");
                checks["azureOpenAI"] = "unhealthy";
                isHealthy = false;
            }

            if (isHealthy)
            {
                return Ok(new { 
                    status = "ready", 
                    timestamp = DateTime.UtcNow,
                    checks = checks
                });
            }
            else
            {
                return StatusCode(503, new { 
                    status = "not ready", 
                    timestamp = DateTime.UtcNow,
                    checks = checks
                });
            }
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