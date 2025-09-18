using CuriousTraveler.Api.Models.Configuration;
using CuriousTraveler.Api.Models.Itinerary;
using CuriousTraveler.Api.Services.Storage;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using System.ComponentModel.DataAnnotations;

namespace CuriousTraveler.Api.Controllers;

[ApiController]
[Route("api/itinerary-jobs")]
public class ItineraryController : ControllerBase
{
    private readonly IQueueService _queueService;
    private readonly ITableStorageService _tableService;
    private readonly ItinerariesOptions _options;
    private readonly ILogger<ItineraryController> _logger;

    public ItineraryController(
        IQueueService queueService,
        ITableStorageService tableService,
        IOptions<ItinerariesOptions> options,
        ILogger<ItineraryController> logger)
    {
        _queueService = queueService;
        _tableService = tableService;
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>
    /// Creates a new itinerary job
    /// </summary>
    /// <param name="request">Itinerary request parameters</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Job ID and status</returns>
    [HttpPost]
    [EnableRateLimiting("ItineraryPostPolicy")]
    [ProducesResponseType(typeof(object), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<IActionResult> CreateItineraryJob(
        [FromBody] ItineraryRequest request,
        CancellationToken cancellationToken = default)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            // Validate request business rules
            var validationErrors = ValidateItineraryRequest(request);
            if (validationErrors.Any())
            {
                foreach (var error in validationErrors)
                {
                    ModelState.AddModelError("", error);
                }
                return BadRequest(ModelState);
            }

            // Create job
            var jobId = Guid.NewGuid().ToString();
            var job = new ItineraryJob
            {
                JobId = jobId,
                Status = JobStatus.Processing,
                Request = request,
                CreatedAt = DateTime.UtcNow,
                ProcessingAttempts = 0,
                ExpiresAt = DateTime.UtcNow.AddHours(_options.JobTtlHours)
            };

            // Persist job
            _logger.LogDebug("DEBUG: Persisting job {JobId} to table storage", jobId);
            await _tableService.CreateJobAsync(job, cancellationToken);
            _logger.LogDebug("DEBUG: Successfully persisted job {JobId} to table storage", jobId);

            // Enqueue for processing
            _logger.LogDebug("DEBUG: Enqueuing job {JobId} for background processing", jobId);
            await _queueService.EnqueueJobAsync(jobId, cancellationToken);
            _logger.LogDebug("DEBUG: Successfully enqueued job {JobId} for background processing", jobId);

            _logger.LogInformation("Created itinerary job {JobId} for route from ({StartLat},{StartLon}) to ({EndLat},{EndLon})",
                jobId, request.Start.Lat, request.Start.Lon, request.End.Lat, request.End.Lon);

            // Return 202 Accepted with location header
            var locationUrl = Url.Action(nameof(GetItineraryJob), new { id = jobId });
            Response.Headers.Location = locationUrl;
            Response.Headers["Retry-After"] = _options.ProcessingRetryAfterSeconds.ToString();

            return Accepted(new { jobId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create itinerary job");
            return StatusCode(500, new { error = "Failed to create itinerary job" });
        }
    }

    /// <summary>
    /// Gets the status and result of an itinerary job
    /// </summary>
    /// <param name="id">Job ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Job status and result if completed</returns>
    [HttpGet("{id}")]
    [EnableRateLimiting("ItineraryGetPolicy")]
    [ProducesResponseType(typeof(ItineraryJobResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ItineraryJobResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<IActionResult> GetItineraryJob(
        [FromRoute] string id,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(id) || !Guid.TryParse(id, out _))
        {
            return BadRequest(new { error = "Invalid job ID format" });
        }

        try
        {
            var job = await _tableService.GetJobAsync(id, cancellationToken);
            if (job == null)
            {
                return NotFound(new 
                { 
                    code = "NO_ITINERARY", 
                    reason = "Job not found or expired" 
                });
            }

            // Check if job is expired
            if (job.ExpiresAt < DateTime.UtcNow)
            {
                return StatusCode(410, new 
                { 
                    code = "NO_ITINERARY", 
                    reason = "Job expired" 
                });
            }

            var response = new ItineraryJobResponse
            {
                JobId = job.JobId,
                Status = job.Status
            };

            switch (job.Status)
            {
                case JobStatus.Processing:
                    Response.Headers["Retry-After"] = _options.ProcessingRetryAfterSeconds.ToString();
                    return Accepted(response);

                case JobStatus.Completed:
                    if (!string.IsNullOrEmpty(job.ResultJson))
                    {
                        response.Result = System.Text.Json.JsonSerializer.Deserialize<ItineraryResult>(
                            job.ResultJson,
                            new System.Text.Json.JsonSerializerOptions
                            {
                                PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
                            });
                    }
                    return Ok(response);

                case JobStatus.Failed:
                    var errorCode = job.FailureReason switch
                    {
                        FailureReason.CommuteExceedsBudget => "commute_exceeds_budget",
                        FailureReason.NoOpenPois => "no_open_pois",
                        FailureReason.NoPoisInIsochrone => "no_pois_in_isochrone",
                        FailureReason.RoutingFailed => "routing_failed",
                        _ => "internal_error"
                    };

                    return NotFound(new 
                    { 
                        code = "NO_ITINERARY", 
                        reason = errorCode,
                        message = job.ErrorMessage 
                    });

                default:
                    return StatusCode(500, new { error = "Unknown job status" });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get itinerary job {JobId}", id);
            return StatusCode(500, new { error = "Failed to retrieve job status" });
        }
    }

    private List<string> ValidateItineraryRequest(ItineraryRequest request)
    {
        var errors = new List<string>();

        // Validate coordinates
        if (request.Start.Lat < -90 || request.Start.Lat > 90)
            errors.Add("Start latitude must be between -90 and 90");
        if (request.Start.Lon < -180 || request.Start.Lon > 180)
            errors.Add("Start longitude must be between -180 and 180");
        if (request.End.Lat < -90 || request.End.Lat > 90)
            errors.Add("End latitude must be between -90 and 90");
        if (request.End.Lon < -180 || request.End.Lon > 180)
            errors.Add("End longitude must be between -180 and 180");

        // Validate time budget
        if (request.MaxDurationMinutes < 60)
            errors.Add("Maximum duration must be at least 60 minutes");
        if (request.MaxDurationMinutes > 720)
            errors.Add("Maximum duration cannot exceed 12 hours (720 minutes)");

        // Validate interests
        if (string.IsNullOrWhiteSpace(request.Interests))
            errors.Add("Interests cannot be empty");
        if (request.Interests.Length > 500)
            errors.Add("Interests description is too long (maximum 500 characters)");

        // Validate language
        var supportedLanguages = new[] { "en", "es", "fr", "de", "it", "pt", "ru", "ja", "ko", "zh" };
        if (!supportedLanguages.Contains(request.Language.ToLowerInvariant()))
            errors.Add($"Language '{request.Language}' is not supported");

        return errors;
    }
}