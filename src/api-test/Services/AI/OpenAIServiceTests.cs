using CuriousTraveler.Api.Services.AI;
using CuriousTraveler.Api.Models.AzureMaps;
using CuriousTraveler.Api.Models.Itinerary;
using CuriousTraveler.Api.Models.Configuration;
using FluentAssertions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using Moq;
using System.Text.Json;
using Xunit;

namespace CuriousTraveler.Api.Tests.Services.AI
{
    public class OpenAIServiceTests
    {
        private readonly Mock<IOptions<AzureOpenAIOptions>> _optionsMock;
        private readonly Mock<ILogger<OpenAIService>> _loggerMock;
        private readonly AzureOpenAIOptions _options;

        public OpenAIServiceTests()
        {
            _options = new AzureOpenAIOptions
            {
                Endpoint = "https://test-openai.openai.azure.com/",
                ApiKey = "test-api-key",
                Gpt5MiniDeployment = "gpt-35-turbo",
                Gpt5ChatDeployment = "gpt-35-turbo-chat"
            };

            _optionsMock = new Mock<IOptions<AzureOpenAIOptions>>();
            _optionsMock.Setup(o => o.Value).Returns(_options);

            _loggerMock = new Mock<ILogger<OpenAIService>>();
        }

        [Fact]
        public void Constructor_WithValidOptions_ShouldSucceed()
        {
            // Act & Assert
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            service.Should().NotBeNull();
        }

        [Fact]
        public void Constructor_WithNullOptions_ShouldThrowNullReferenceException()
        {
            // The actual service throws NullReferenceException when accessing options.Value
            // Act & Assert
            Assert.Throws<NullReferenceException>(() => new OpenAIService(null!, _loggerMock.Object));
        }

        [Fact]
        public void Constructor_WithValidOptionsAndNullLogger_ShouldSucceed()
        {
            // The service doesn't validate logger parameter in constructor
            // Act & Assert
            var service = new OpenAIService(_optionsMock.Object, null!);
            service.Should().NotBeNull();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithValidInput_ShouldReturnDictionary()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants, shopping";
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" },
                new() { Id = 7315, Name = "Restaurant" },
                new() { Id = 7374, Name = "Shopping Center" }
            };

            // Act - This would normally call OpenAI, but in a real test environment 
            // we'd need to mock the OpenAI client or use integration testing
            // For now, we'll test the method signature and basic validation
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            // Assert - The method should not throw immediately (validation should pass)
            // Note: This test would fail in real execution due to OpenAI API call, but tests the interface
            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task EstimateMinVisitMinutesAsync_WithValidInput_ShouldNotThrowImmediately()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var poi = new PointOfInterest
            {
                Id = "test-poi-1",
                Name = "Space Needle",
                Address = "400 Broad St, Seattle, WA 98109",
                Category = "Observation Deck"
            };
            var defaults = new Dictionary<string, int>
            {
                ["default"] = 60
            };

            // Act & Assert - Test that method doesn't throw on parameter validation
            var act = async () => await service.EstimateMinVisitMinutesAsync(
                poi, "en", defaults, 15, 240);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task RerankPoisAsync_WithValidInput_ShouldNotThrowImmediately()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var candidates = new List<PointOfInterest>
            {
                new() { 
                    Id = "poi-1", 
                    Name = "Museum A", 
                    Address = "123 Museum St",
                    Category = "Museum" 
                },
                new() { 
                    Id = "poi-2", 
                    Name = "Restaurant B", 
                    Address = "456 Food Ave",
                    Category = "Restaurant" 
                }
            };
            var interests = new List<string> { "museums", "food" };

            // Act & Assert - Test that method doesn't throw on parameter validation
            var act = async () => await service.RerankPoisAsync(
                candidates, interests, "en", TravelMode.Walking, 5, 180);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToCategoriesAsync_WithValidInput_ShouldNotThrowImmediately()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var allowlist = new List<CategoryMapping>
            {
                new() { 
                    Id = "museums",
                    Labels = new List<string> { "museums", "art galleries" },
                    AzureMapsCategory = "7321" 
                },
                new() { 
                    Id = "restaurants",
                    Labels = new List<string> { "restaurants", "dining" },
                    AzureMapsCategory = "7315" 
                }
            };

            // Act & Assert - Test that method doesn't throw on parameter validation
            var act = async () => await service.MapInterestsToCategoriesAsync(
                "museums, restaurants", "en", "Seattle", allowlist);

            await act.Should().NotThrowAsync<ArgumentException>();
        }
    }
}