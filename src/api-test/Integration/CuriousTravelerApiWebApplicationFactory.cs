using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Services.Storage;
using CuriousTraveler.Api.Services.AI;
using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Models.Itinerary;
using CuriousTraveler.Api.Models.AzureMaps;
using Moq;

namespace CuriousTraveler.Api.Tests.Integration;

public class CuriousTravelerApiWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AzureMaps:AccountName"] = "test-maps-account",
                ["AzureMaps:SubscriptionKey"] = "test-subscription-key",
                ["ApplicationInsights:ConnectionString"] = "InstrumentationKey=test-key",
                ["Storage:ConnectionString"] = "UseDevelopmentStorage=true",
                ["Storage:QueueName"] = "test-queue",
                ["Storage:TableName"] = "test-table",
                ["AzureOpenAI:Endpoint"] = "https://test-openai.openai.azure.com/",
                ["AzureOpenAI:ApiKey"] = "test-api-key",
                ["AzureOpenAI:Gpt5MiniDeployment"] = "gpt-35-turbo",
                ["Logging:LogLevel:Default"] = "Information"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove real services
            RemoveServices<IAzureMapsService>(services);
            RemoveServices<IQueueService>(services);
            RemoveServices<ITableStorageService>(services);
            RemoveServices<IOpenAIService>(services);

            // Add mocks
            AddMockAzureMapsService(services);
            AddMockStorageServices(services);
            AddMockOpenAIService(services);
        });
    }

    private static void RemoveServices<T>(IServiceCollection services)
    {
        var descriptors = services.Where(d => d.ServiceType == typeof(T)).ToList();
        foreach (var descriptor in descriptors)
        {
            services.Remove(descriptor);
        }
    }

    private static void AddMockAzureMapsService(IServiceCollection services)
    {
        var mock = new Mock<IAzureMapsService>();
        
        // Mock SearchPoisAsync method with correct signature
        mock.Setup(m => m.SearchPoisAsync(It.IsAny<LocationPoint>(), It.IsAny<List<int>>(), 
            It.IsAny<double>(), It.IsAny<int>()))
            .ReturnsAsync(new List<PointOfInterest>
            {
                new PointOfInterest
                {
                    Id = "test-poi-1",
                    Name = "Test POI",
                    Address = "123 Test St",
                    Latitude = 47.6062,
                    Longitude = -122.3321,
                    Category = "restaurant",
                    Rating = 4.5,
                    EstimatedMinVisitMinutes = 60
                }
            });
        
        // Mock other required methods
        mock.Setup(m => m.ReverseGeocodeAsync(It.IsAny<double>(), It.IsAny<double>(), It.IsAny<string>()))
            .ReturnsAsync(new ReverseGeocodeResponse
            {
                FormattedAddress = "Test Address, Test City, Test Country",
                Locality = "Test City",
                CountryCode = "US",
                Center = new GeocodePosition { Latitude = 47.6062, Longitude = -122.3321 }
            });

        mock.Setup(m => m.SearchAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()))
            .ReturnsAsync(new List<GeocodeSearchResult>
            {
                new GeocodeSearchResult
                {
                    Name = "Test Location",
                    Type = "POI",
                    FormattedAddress = "Test Address",
                    Locality = "Test City",
                    CountryCode = "US",
                    Position = new GeocodePosition { Latitude = 47.6062, Longitude = -122.3321 },
                    Confidence = "High"
                }
            });

        mock.Setup(m => m.GetAccessTokenAsync())
            .ReturnsAsync(new AzureMapsToken
            {
                AccessToken = "test-token",
                ExpiresAt = DateTime.UtcNow.AddMinutes(30)
            });

        services.AddSingleton(mock.Object);
    }

    private static void AddMockStorageServices(IServiceCollection services)
    {
        var mockQueue = new Mock<IQueueService>();
        var mockTable = new Mock<ITableStorageService>();
        services.AddSingleton(mockQueue.Object);
        services.AddSingleton(mockTable.Object);
    }

    private static void AddMockOpenAIService(IServiceCollection services)
    {
        var mock = new Mock<IOpenAIService>();
        mock.Setup(s => s.MapInterestsToAzureMapsCategoriesAsync(
            It.IsAny<string>(), 
            It.IsAny<string>(), 
            It.IsAny<string>(), 
            It.IsAny<List<PoiCategory>>(), 
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Dictionary<string, List<int>>
            {
                ["restaurants"] = new List<int> { 7315 },
                ["attractions"] = new List<int> { 9361, 9362 }
            });
        services.AddSingleton(mock.Object);
    }
}