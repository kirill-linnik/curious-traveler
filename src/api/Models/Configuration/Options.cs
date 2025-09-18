using System.ComponentModel.DataAnnotations;

namespace CuriousTraveler.Api.Models.Configuration;

public class ItinerariesOptions
{
    public const string Section = "Itineraries";

    [Range(1, 10)]
    public int MaxPois { get; set; } = 5;
    
    public bool UseIsochroneIfAvailable { get; set; } = true;
    
    public bool StrictOpeningHours { get; set; } = true;
    
    public required Dictionary<string, double> DefaultRadiusKm { get; set; }
    
    public required Dictionary<string, double> AvgSpeedsKmh { get; set; }
    
    [Range(1, 60)]
    public int ProcessingRetryAfterSeconds { get; set; } = 3;
    
    [Range(1, 168)]
    public int JobTtlHours { get; set; } = 24;
    
    public required List<CategoryMapping> CategoryMappings { get; set; }
}

public class CategoryMapping
{
    public required string Id { get; set; }
    public required List<string> Labels { get; set; }
    public required string AzureMapsCategory { get; set; }
}

public class AzureMapsOptions
{
    public const string Section = "AzureMaps";

    [Required]
    public required string AuthMode { get; set; } // "AAD" or "KEY"
    
    public string? AccountName { get; set; }
    
    public bool TransitEnabledHint { get; set; } = true;
}

public class AzureOpenAIOptions
{
    public const string Section = "AzureOpenAI";

    [Required]
    public required string Endpoint { get; set; }
    
    [Required]
    public required string ApiKey { get; set; }
    
    [Required]
    public required string Gpt5MiniDeployment { get; set; }
    
    [Required]
    public required string Gpt5ChatDeployment { get; set; }
    
    [Range(5, 120)]
    public int TimeoutSeconds { get; set; } = 30;
    
    [Range(0, 3)]
    public int MaxRetries { get; set; } = 1;
}

public class StorageOptions
{
    public const string Section = "Storage";

    [Required]
    public required string ConnectionString { get; set; }
    
    [Required]
    public required string QueueName { get; set; }
    
    [Required]
    public required string JobsTable { get; set; }
}

public class RateLimitingOptions
{
    public const string Section = "RateLimiting";

    [Range(1, 100)]
    public int PostPerMinute { get; set; } = 20;
    
    [Range(1, 200)]
    public int GetPerMinute { get; set; } = 60;
}