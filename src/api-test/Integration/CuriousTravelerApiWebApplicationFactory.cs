using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Models;
using Moq;

namespace CuriousTraveler.Api.Tests.Integration;

public class CuriousTravelerApiWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, config) =>
        {
            // Add test configuration
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AZURE_MAPS_ACCOUNT_ID"] = "test-maps-account",
                ["AZURE_MAPS_AUTH_MODE"] = "AAD",
                ["ApplicationInsights:ConnectionString"] = "InstrumentationKey=test-key",
                ["Logging:LogLevel:Default"] = "Information"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove all real Azure Maps service registrations and add a mock
            var descriptors = services.Where(d => d.ServiceType == typeof(IAzureMapsService)).ToList();
            foreach (var descriptor in descriptors)
            {
                services.Remove(descriptor);
            }

            // Remove HttpClient registration for the Azure Maps service
            var httpClientDescriptor = services.SingleOrDefault(d => 
                d.ServiceType == typeof(HttpClient) || 
                d.ImplementationType?.Name.Contains("AzureMapsService") == true);
            
            // Add mock Azure Maps service
            var mockService = new Mock<IAzureMapsService>();
            
            // Setup mock responses
            mockService.Setup(s => s.ReverseGeocodeAsync(It.IsAny<double>(), It.IsAny<double>(), It.IsAny<string>()))
                .ReturnsAsync(new ReverseGeocodeResponse
                {
                    FormattedAddress = "Test Address, Test City, Test Country",
                    Locality = "Test City",
                    CountryCode = "US",
                    Center = new GeocodePosition { Latitude = 47.6062, Longitude = -122.3321 }
                });

            mockService.Setup(s => s.SearchAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()))
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

            mockService.Setup(s => s.GetAccessTokenAsync())
                .ReturnsAsync(new AzureMapsToken
                {
                    AccessToken = "test-token",
                    ExpiresAt = DateTime.UtcNow.AddHours(1)
                });

            services.AddSingleton(mockService.Object);
        });

        builder.UseEnvironment("Testing");
    }
}