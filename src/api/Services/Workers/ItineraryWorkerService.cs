using CuriousTraveler.Api.Models.Itinerary;
using CuriousTraveler.Api.Services.Business;
using CuriousTraveler.Api.Services.Storage;
using System.Text.Json;
using Azure.Storage.Queues.Models;

namespace CuriousTraveler.Api.Services.Workers;

public class ItineraryWorkerService : BackgroundService
{
    private readonly IQueueService _queueService;
    private readonly ITableStorageService _tableService;
    private readonly IItineraryBuilderService _itineraryBuilder;
    private readonly ILogger<ItineraryWorkerService> _logger;

    public ItineraryWorkerService(
        IQueueService queueService,
        ITableStorageService tableService,
        IItineraryBuilderService itineraryBuilder,
        ILogger<ItineraryWorkerService> logger)
    {
        _queueService = queueService;
        _tableService = tableService;
        _itineraryBuilder = itineraryBuilder;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Itinerary worker service started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessJobsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in itinerary worker service");
            }

            // Wait before checking for more jobs - reduced for better responsiveness
            await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
        }

        _logger.LogInformation("Itinerary worker service stopped");
    }

    private async Task ProcessJobsAsync(CancellationToken cancellationToken)
    {
        var message = await _queueService.DequeueJobAsync(cancellationToken);
        if (message == null)
        {
            return; // No messages to process - don't log for empty queue
        }

        _logger.LogDebug("DEBUG: Found message in queue with ID: {MessageId}", message.MessageId);

        string? jobId = null;
        try
        {
            // Parse the job message
            _logger.LogDebug("DEBUG: Parsing message body: {MessageBody}", message.Body.ToString());
            var messageData = JsonSerializer.Deserialize<Dictionary<string, object>>(message.Body.ToString());
            jobId = messageData?["JobId"]?.ToString();

            if (string.IsNullOrEmpty(jobId))
            {
                _logger.LogError("Invalid message format: missing JobId");
                await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                return;
            }

            _logger.LogInformation("Processing job {JobId}", jobId);
            _logger.LogDebug("DEBUG: Retrieving job {JobId} from table storage...", jobId);

            // Get the job from storage
            var job = await _tableService.GetJobAsync(jobId, cancellationToken);
            if (job == null)
            {
                _logger.LogWarning("Job {JobId} not found in storage", jobId);
                await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                return;
            }

            _logger.LogDebug("DEBUG: Found job {JobId} with status {Status}, created at {CreatedAt}", 
                jobId, job.Status, job.CreatedAt);

            // Check if job is already processed or expired
            if (job.Status != JobStatus.Processing)
            {
                _logger.LogInformation("Job {JobId} already processed with status {Status}", jobId, job.Status);
                await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                return;
            }

            if (job.ExpiresAt < DateTime.UtcNow)
            {
                _logger.LogInformation("Job {JobId} expired", jobId);
                await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
                return;
            }

            _logger.LogDebug("DEBUG: Job {JobId} is valid and ready for processing", jobId);

            // Process the itinerary
            _logger.LogDebug("DEBUG: Starting itinerary processing for job {JobId}", jobId);
            await ProcessItineraryJobAsync(job, cancellationToken);
            _logger.LogDebug("DEBUG: Completed itinerary processing for job {JobId}", jobId);

            // Delete the message after successful processing
            _logger.LogDebug("DEBUG: Deleting processed message {MessageId} for job {JobId}", message.MessageId, jobId);
            await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);

            _logger.LogInformation("Successfully processed job {JobId}", jobId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process job {JobId}", jobId ?? "unknown");

            // Update job status to failed if we have the jobId
            if (!string.IsNullOrEmpty(jobId))
            {
                try
                {
                    var job = await _tableService.GetJobAsync(jobId, cancellationToken);
                    if (job != null)
                    {
                        job.Status = JobStatus.Failed;
                        job.FailureReason = FailureReason.InternalError;
                        job.ErrorMessage = ex.Message;
                        job.CompletedAt = DateTime.UtcNow;
                        job.ProcessingAttempts++;

                        await _tableService.UpdateJobAsync(job, cancellationToken);
                    }
                }
                catch (Exception updateEx)
                {
                    _logger.LogError(updateEx, "Failed to update job {JobId} status to failed", jobId);
                }
            }

            // Delete the message to avoid reprocessing
            await _queueService.DeleteJobMessageAsync(message.MessageId, message.PopReceipt, cancellationToken);
        }
    }

    private async Task ProcessItineraryJobAsync(
        ItineraryJob job,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogDebug("DEBUG: Starting ProcessItineraryJobAsync for job {JobId}", job.JobId);
            
            // Increment processing attempts
            job.ProcessingAttempts++;
            _logger.LogDebug("DEBUG: Incrementing processing attempts to {Attempts} for job {JobId}", 
                job.ProcessingAttempts, job.JobId);
            await _tableService.UpdateJobAsync(job, cancellationToken);
            _logger.LogDebug("DEBUG: Updated job {JobId} with processing attempt count", job.JobId);

            _logger.LogInformation("Building itinerary for job {JobId}, attempt {Attempt}", 
                job.JobId, job.ProcessingAttempts);

            _logger.LogDebug("DEBUG: Calling ItineraryBuilderService.BuildItineraryAsync for job {JobId}", job.JobId);
            // Build the itinerary
            var result = await _itineraryBuilder.BuildItineraryAsync(job.Request, cancellationToken);
            _logger.LogDebug("DEBUG: ItineraryBuilderService.BuildItineraryAsync completed successfully for job {JobId}", job.JobId);

            _logger.LogDebug("DEBUG: Updating job {JobId} status to Completed", job.JobId);
            // Update job with successful result
            job.Status = JobStatus.Completed;
            job.ResultJson = JsonSerializer.Serialize(result, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });
            job.CompletedAt = DateTime.UtcNow;

            _logger.LogDebug("DEBUG: Persisting completed job {JobId} to table storage", job.JobId);
            await _tableService.UpdateJobAsync(job, cancellationToken);
            _logger.LogDebug("DEBUG: Successfully persisted completed job {JobId}", job.JobId);

            _logger.LogInformation("Successfully built itinerary for job {JobId} with {StopsCount} stops", 
                job.JobId, result.Stops.Count);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("COMMUTE_EXCEEDS_BUDGET"))
        {
            _logger.LogWarning("Job {JobId} failed: commute exceeds budget", job.JobId);
            
            job.Status = JobStatus.Failed;
            job.FailureReason = FailureReason.CommuteExceedsBudget;
            job.ErrorMessage = "The travel time between start and end points exceeds the available time budget";
            job.CompletedAt = DateTime.UtcNow;

            await _tableService.UpdateJobAsync(job, cancellationToken);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("NO_OPEN_POIS"))
        {
            _logger.LogWarning("Job {JobId} failed: no open POIs", job.JobId);
            
            job.Status = JobStatus.Failed;
            job.FailureReason = FailureReason.NoOpenPois;
            job.ErrorMessage = "No points of interest are open during the requested time window";
            job.CompletedAt = DateTime.UtcNow;

            await _tableService.UpdateJobAsync(job, cancellationToken);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("NO_POIS_IN_ISOCHRONE"))
        {
            _logger.LogWarning("Job {JobId} failed: no POIs in reachable area", job.JobId);
            
            job.Status = JobStatus.Failed;
            job.FailureReason = FailureReason.NoPoisInIsochrone;
            job.ErrorMessage = "No points of interest found within the reachable area";
            job.CompletedAt = DateTime.UtcNow;

            await _tableService.UpdateJobAsync(job, cancellationToken);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("ROUTING_FAILED"))
        {
            _logger.LogWarning("Job {JobId} failed: routing failed", job.JobId);
            
            job.Status = JobStatus.Failed;
            job.FailureReason = FailureReason.RoutingFailed;
            job.ErrorMessage = "Failed to calculate routes between locations";
            job.CompletedAt = DateTime.UtcNow;

            await _tableService.UpdateJobAsync(job, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error processing job {JobId}", job.JobId);
            
            job.Status = JobStatus.Failed;
            job.FailureReason = FailureReason.InternalError;
            job.ErrorMessage = "An internal error occurred while processing the request";
            job.CompletedAt = DateTime.UtcNow;

            await _tableService.UpdateJobAsync(job, cancellationToken);
            
            throw; // Re-throw for worker error handling
        }
    }
}