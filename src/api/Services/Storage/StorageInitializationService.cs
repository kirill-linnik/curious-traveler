using Azure.Data.Tables;
using Azure.Storage.Queues;
using CuriousTraveler.Api.Models.Configuration;
using Microsoft.Extensions.Options;

namespace CuriousTraveler.Api.Services.Storage;

/// <summary>
/// Service responsible for initializing Azure Storage resources during application startup
/// </summary>
public interface IStorageInitializationService
{
    Task InitializeAsync(CancellationToken cancellationToken = default);
}

public class StorageInitializationService : IStorageInitializationService
{
    private readonly StorageOptions _storageOptions;
    private readonly ILogger<StorageInitializationService> _logger;

    public StorageInitializationService(
        IOptions<StorageOptions> storageOptions,
        ILogger<StorageInitializationService> logger)
    {
        _storageOptions = storageOptions.Value;
        _logger = logger;
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Initializing Azure Storage resources...");

        try
        {
            // Initialize Queue Storage
            await InitializeQueueStorageAsync(cancellationToken);

            // Initialize Table Storage
            await InitializeTableStorageAsync(cancellationToken);

            _logger.LogInformation("Azure Storage resources initialized successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Azure Storage resources");
            throw;
        }
    }

    private async Task InitializeQueueStorageAsync(CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogDebug("Creating queue if not exists: {QueueName}", _storageOptions.QueueName);
            
            var queueServiceClient = new QueueServiceClient(_storageOptions.ConnectionString);
            var queueClient = queueServiceClient.GetQueueClient(_storageOptions.QueueName);
            
            var response = await queueClient.CreateIfNotExistsAsync(cancellationToken: cancellationToken);
            
            if (response != null)
            {
                _logger.LogInformation("Created new queue: {QueueName}", _storageOptions.QueueName);
            }
            else
            {
                _logger.LogDebug("Queue already exists: {QueueName}", _storageOptions.QueueName);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize queue storage: {QueueName}", _storageOptions.QueueName);
            throw;
        }
    }

    private async Task InitializeTableStorageAsync(CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogDebug("Creating table if not exists: {TableName}", _storageOptions.JobsTable);
            
            var tableServiceClient = new TableServiceClient(_storageOptions.ConnectionString);
            var tableClient = tableServiceClient.GetTableClient(_storageOptions.JobsTable);
            
            var response = await tableClient.CreateIfNotExistsAsync(cancellationToken);
            
            if (response != null)
            {
                _logger.LogInformation("Created new table: {TableName}", _storageOptions.JobsTable);
            }
            else
            {
                _logger.LogDebug("Table already exists: {TableName}", _storageOptions.JobsTable);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize table storage: {TableName}", _storageOptions.JobsTable);
            throw;
        }
    }
}