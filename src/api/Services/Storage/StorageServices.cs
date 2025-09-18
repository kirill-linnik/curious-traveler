using Azure.Data.Tables;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using CuriousTraveler.Api.Models.Itinerary;
using Microsoft.Extensions.Options;
using System.Text.Json;
using CuriousTraveler.Api.Models.Configuration;

namespace CuriousTraveler.Api.Services.Storage;

public interface IQueueService
{
    Task EnqueueJobAsync(string jobId, CancellationToken cancellationToken = default);
    Task<QueueMessage?> DequeueJobAsync(CancellationToken cancellationToken = default);
    Task DeleteJobMessageAsync(string messageId, string popReceipt, CancellationToken cancellationToken = default);
    Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default);
}

public class QueueService : IQueueService
{
    private readonly QueueClient _queueClient;
    private readonly ILogger<QueueService> _logger;
    
    public QueueService(
        IOptions<StorageOptions> storageOptions,
        ILogger<QueueService> logger)
    {
        _logger = logger;
        
        var options = storageOptions.Value;
        _logger.LogDebug("DEBUG: QueueService constructor - Queue name: {QueueName}, Connection string starts with: {ConnectionStart}", 
            options.QueueName, options.ConnectionString?.Substring(0, Math.Min(50, options.ConnectionString?.Length ?? 0)));
        
        var queueServiceClient = new QueueServiceClient(options.ConnectionString);
        _queueClient = queueServiceClient.GetQueueClient(options.QueueName);
        
        _logger.LogDebug("DEBUG: QueueService constructor - Queue client created for queue: {QueueName}", options.QueueName);
    }

    public async Task EnqueueJobAsync(string jobId, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogDebug("DEBUG: EnqueueJobAsync - Creating queue if not exists for job {JobId}", jobId);
            await _queueClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken);
            _logger.LogDebug("DEBUG: EnqueueJobAsync - Queue exists, preparing message for job {JobId}", jobId);
            
            var message = JsonSerializer.Serialize(new { JobId = jobId });
            _logger.LogDebug("DEBUG: EnqueueJobAsync - Sending message to queue: {Message}", message);
            await _queueClient.SendMessageAsync(message, cancellationToken);
            _logger.LogDebug("DEBUG: EnqueueJobAsync - Successfully sent message to queue for job {JobId}", jobId);
            
            _logger.LogInformation("Enqueued job {JobId}", jobId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to enqueue job {JobId}", jobId);
            throw;
        }
    }

    public async Task<QueueMessage?> DequeueJobAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogDebug("DEBUG: DequeueJobAsync - Attempting to receive message from queue");
            var response = await _queueClient.ReceiveMessagesAsync(
                maxMessages: 1,
                visibilityTimeout: TimeSpan.FromMinutes(10), 
                cancellationToken);
            
            if (response.Value != null && response.Value.Length > 0)
            {
                var message = response.Value[0];
                _logger.LogDebug("DEBUG: DequeueJobAsync - Received message: ID={MessageId}, Body={Body}", 
                    message.MessageId, message.Body.ToString());
                return message;
            }
            else
            {
                _logger.LogDebug("DEBUG: DequeueJobAsync - No messages available in queue");
                return null;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to dequeue job message");
            throw;
        }
    }

    public async Task DeleteJobMessageAsync(string messageId, string popReceipt, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogDebug("DEBUG: DeleteJobMessageAsync - Deleting message {MessageId} with pop receipt", messageId);
            await _queueClient.DeleteMessageAsync(messageId, popReceipt, cancellationToken);
            _logger.LogDebug("Deleted message {MessageId}", messageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete message {MessageId}", messageId);
            throw;
        }
    }

    public async Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            // Try to ensure the queue exists and check if we can access the service
            await _queueClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken);
            
            // Try to get queue properties as a connectivity test
            await _queueClient.GetPropertiesAsync(cancellationToken);
            
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Queue storage health check failed");
            return false;
        }
    }
}

public interface ITableStorageService
{
    Task<ItineraryJob?> GetJobAsync(string jobId, CancellationToken cancellationToken = default);
    Task CreateJobAsync(ItineraryJob job, CancellationToken cancellationToken = default);
    Task UpdateJobAsync(ItineraryJob job, CancellationToken cancellationToken = default);
    Task<List<ItineraryJob>> GetExpiredJobsAsync(CancellationToken cancellationToken = default);
}

public class TableStorageService : ITableStorageService
{
    private readonly TableClient _tableClient;
    private readonly ILogger<TableStorageService> _logger;
    
    public TableStorageService(
        IOptions<StorageOptions> storageOptions,
        ILogger<TableStorageService> logger)
    {
        _logger = logger;
        
        var options = storageOptions.Value;
        var tableServiceClient = new TableServiceClient(options.ConnectionString);
        _tableClient = tableServiceClient.GetTableClient(options.JobsTable);
    }

    public async Task<ItineraryJob?> GetJobAsync(string jobId, CancellationToken cancellationToken = default)
    {
        try
        {
            await _tableClient.CreateIfNotExistsAsync(cancellationToken);
            
            var response = await _tableClient.GetEntityIfExistsAsync<ItineraryJobEntity>(
                partitionKey: GetPartitionKey(jobId),
                rowKey: jobId,
                cancellationToken: cancellationToken);
                
            return response.HasValue ? response.Value?.ToItineraryJob() : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get job {JobId}", jobId);
            throw;
        }
    }

    public async Task CreateJobAsync(ItineraryJob job, CancellationToken cancellationToken = default)
    {
        try
        {
            await _tableClient.CreateIfNotExistsAsync(cancellationToken);
            
            var entity = ItineraryJobEntity.FromItineraryJob(job);
            await _tableClient.AddEntityAsync(entity, cancellationToken);
            
            _logger.LogInformation("Created job {JobId}", job.JobId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create job {JobId}", job.JobId);
            throw;
        }
    }

    public async Task UpdateJobAsync(ItineraryJob job, CancellationToken cancellationToken = default)
    {
        try
        {
            var entity = ItineraryJobEntity.FromItineraryJob(job);
            var response = await _tableClient.UpdateEntityAsync(entity, entity.ETag, cancellationToken: cancellationToken);
            
            // Update the job's ETag with the new value from the response
            job.ETag = response.Headers.ETag;
            
            _logger.LogInformation("Updated job {JobId} with status {Status}", job.JobId, job.Status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to update job {JobId}", job.JobId);
            throw;
        }
    }

    public async Task<List<ItineraryJob>> GetExpiredJobsAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var query = _tableClient.QueryAsync<ItineraryJobEntity>(
                filter: $"ExpiresAt lt datetime'{DateTime.UtcNow:yyyy-MM-ddTHH:mm:ssZ}'",
                cancellationToken: cancellationToken);

            var expiredJobs = new List<ItineraryJob>();
            await foreach (var entity in query)
            {
                expiredJobs.Add(entity.ToItineraryJob());
            }

            return expiredJobs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get expired jobs");
            throw;
        }
    }

    private static string GetPartitionKey(string jobId)
    {
        // Use the first character for simple partitioning
        return jobId[0].ToString().ToUpper();
    }
}

// Table entity for Azure Tables
public class ItineraryJobEntity : ITableEntity
{
    public string PartitionKey { get; set; } = "";
    public string RowKey { get; set; } = "";
    public DateTimeOffset? Timestamp { get; set; }
    public Azure.ETag ETag { get; set; }
    
    public string Status { get; set; } = "";
    public string RequestJson { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? ResultJson { get; set; }
    public string? FailureReason { get; set; }
    public string? ErrorMessage { get; set; }
    public int ProcessingAttempts { get; set; }
    public DateTime ExpiresAt { get; set; }

    public static ItineraryJobEntity FromItineraryJob(ItineraryJob job)
    {
        return new ItineraryJobEntity
        {
            PartitionKey = job.JobId[0].ToString().ToUpper(),
            RowKey = job.JobId,
            Status = job.Status.ToString(),
            RequestJson = JsonSerializer.Serialize(job.Request),
            CreatedAt = job.CreatedAt,
            CompletedAt = job.CompletedAt,
            ResultJson = job.ResultJson,
            FailureReason = job.FailureReason?.ToString(),
            ErrorMessage = job.ErrorMessage,
            ProcessingAttempts = job.ProcessingAttempts,
            ExpiresAt = job.ExpiresAt,
            ETag = job.ETag ?? default(Azure.ETag)
        };
    }

    public ItineraryJob ToItineraryJob()
    {
        return new ItineraryJob
        {
            JobId = RowKey,
            Status = Enum.Parse<JobStatus>(Status),
            Request = JsonSerializer.Deserialize<ItineraryRequest>(RequestJson) 
                ?? throw new InvalidOperationException("Failed to deserialize request"),
            CreatedAt = CreatedAt,
            CompletedAt = CompletedAt,
            ResultJson = ResultJson,
            FailureReason = FailureReason != null ? Enum.Parse<FailureReason>(FailureReason) : null,
            ErrorMessage = ErrorMessage,
            ProcessingAttempts = ProcessingAttempts,
            ExpiresAt = ExpiresAt,
            ETag = ETag
        };
    }
}