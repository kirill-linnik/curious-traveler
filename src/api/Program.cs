using CuriousTraveler.Api.Middleware;
using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Services.AI;
using CuriousTraveler.Api.Services.Business;
using CuriousTraveler.Api.Services.Storage;
using CuriousTraveler.Api.Services.Workers;
using CuriousTraveler.Api.Models.Configuration;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);

// Configure logging with timestamps
builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(options =>
{
    options.TimestampFormat = "[yyyy-MM-dd HH:mm:ss.fff] ";
    options.IncludeScopes = true;
    options.SingleLine = false;
});

// Add Application Insights
builder.Services.AddApplicationInsightsTelemetry();

// Add controllers
builder.Services.AddControllers();

// Add API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "Curious Traveler API", 
        Version = "v1",
        Description = "ASP.NET Core Web API for the Curious Traveler mobile app with async itinerary creation"
    });
    
    // Include XML comments if available
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
});

// Add memory cache
builder.Services.AddMemoryCache();

// Configure options
builder.Services.Configure<ItinerariesOptions>(
    builder.Configuration.GetSection(ItinerariesOptions.Section));
builder.Services.Configure<AzureMapsOptions>(
    builder.Configuration.GetSection(AzureMapsOptions.Section));
builder.Services.Configure<AzureOpenAIOptions>(
    builder.Configuration.GetSection(AzureOpenAIOptions.Section));
builder.Services.Configure<StorageOptions>(
    builder.Configuration.GetSection(StorageOptions.Section));
builder.Services.Configure<RateLimitingOptions>(
    builder.Configuration.GetSection(RateLimitingOptions.Section));

// Add HTTP clients
builder.Services.AddHttpClient<IAzureMapsService, AzureMapsService>();

// Add custom services as singletons to prevent constant re-initialization in background worker
builder.Services.AddSingleton<IAzureMapsService, AzureMapsService>();
builder.Services.AddSingleton<IOpenAIService, OpenAIService>();
builder.Services.AddSingleton<IItineraryBuilderService, ItineraryBuilderService>();
builder.Services.AddSingleton<IQueueService, QueueService>();
builder.Services.AddSingleton<ITableStorageService, TableStorageService>();

// Add storage initialization service
builder.Services.AddSingleton<IStorageInitializationService, StorageInitializationService>();

// Add background services
builder.Services.AddHostedService<ItineraryWorkerService>();

// Add rate limiting
var rateLimitingOptions = new RateLimitingOptions();
builder.Configuration.GetSection(RateLimitingOptions.Section).Bind(rateLimitingOptions);

builder.Services.AddRateLimiter(options =>
{
    // Existing rate limiting policies
    options.AddFixedWindowLimiter("GeocodingPolicy", limiterOptions =>
    {
        limiterOptions.PermitLimit = 60;
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOptions.QueueLimit = 10;
    });
    
    options.AddFixedWindowLimiter("MapsPolicy", limiterOptions =>
    {
        limiterOptions.PermitLimit = 100;
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOptions.QueueLimit = 20;
    });

    // New rate limiting policies for itinerary endpoints
    options.AddFixedWindowLimiter("ItineraryPostPolicy", limiterOptions =>
    {
        limiterOptions.PermitLimit = rateLimitingOptions.PostPerMinute;
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOptions.QueueLimit = 5;
    });

    options.AddFixedWindowLimiter("ItineraryGetPolicy", limiterOptions =>
    {
        limiterOptions.PermitLimit = rateLimitingOptions.GetPerMinute;
        limiterOptions.Window = TimeSpan.FromMinutes(1);
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOptions.QueueLimit = 10;
    });
    
    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        await context.HttpContext.Response.WriteAsync(
            "Rate limit exceeded. Please try again later.", token);
    };
});

// Add CORS
var allowedOrigins = builder.Configuration["ALLOWED_ORIGINS"]?.Split(',', StringSplitOptions.RemoveEmptyEntries) 
                    ?? new[] { "http://localhost:3000", "https://localhost:3001" };

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .WithMethods("GET", "POST")
              .WithHeaders("Content-Type", "Accept", "Accept-Language")
              .SetIsOriginAllowedToAllowWildcardSubdomains();
    });
});

var app = builder.Build();

// Initialize Azure Storage resources (queues and tables)
try
{
    using var scope = app.Services.CreateScope();
    var storageInitService = scope.ServiceProvider.GetRequiredService<IStorageInitializationService>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    logger.LogInformation("Initializing Azure Storage resources on startup...");
    await storageInitService.InitializeAsync();
    logger.LogInformation("Azure Storage resources initialization completed successfully");
}
catch (Exception ex)
{
    // Log the error but don't prevent startup - the services will attempt to create resources when needed
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogWarning(ex, "Failed to initialize Azure Storage resources during startup. Resources will be created on first use.");
}

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("Testing"))
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Curious Traveler API v1");
        c.RoutePrefix = string.Empty; // Serve Swagger UI at root
    });
}

// Add global exception handling
app.UseMiddleware<GlobalExceptionMiddleware>();

// Security headers
app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    
    await next();
});

// Force HTTPS in production
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors();
app.UseRateLimiter();

app.UseAuthorization();

app.MapControllers();

// Health endpoints
app.MapGet("/healthz", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
   .WithTags("Health")
   .WithSummary("Liveness probe");

app.MapGet("/readyz", () => Results.Ok(new { status = "ready", timestamp = DateTime.UtcNow }))
   .WithTags("Health")
   .WithSummary("Readiness probe");

app.Run();

// Make the implicit Program class public for testing
public partial class Program { }