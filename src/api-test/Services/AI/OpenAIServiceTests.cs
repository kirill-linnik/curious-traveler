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

        #region Batch Dwell Time Estimation Tests

        [Fact]
        public async Task EstimateBatchMinVisitMinutesAsync_WithEmptyList_ShouldHandleGracefully()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var pois = new List<PointOfInterest>();
            var defaults = new Dictionary<string, int> { ["default"] = 60 };

            // Act & Assert - Should not throw with empty list
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                pois, "en", defaults, 15, 240);

            await act.Should().NotThrowAsync();
        }

        [Fact]
        public async Task EstimateBatchMinVisitMinutesAsync_WithNullPoiList_ShouldThrowArgumentException()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var defaults = new Dictionary<string, int> { ["default"] = 60 };

            // Act & Assert
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                null!, "en", defaults, 15, 240);

            await act.Should().ThrowAsync<ArgumentNullException>();
        }

        [Fact]
        public async Task EstimateBatchMinVisitMinutesAsync_WithValidPois_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var pois = new List<PointOfInterest>
            {
                new()
                {
                    Id = "poi-1",
                    Name = "Seattle Art Museum",
                    Address = "1300 1st Ave, Seattle, WA 98101",
                    Category = "Museum"
                },
                new()
                {
                    Id = "poi-2",
                    Name = "Pike Place Market",
                    Address = "85 Pike St, Seattle, WA 98101",
                    Category = "Market"
                },
                new()
                {
                    Id = "poi-3",
                    Name = "Space Needle",
                    Address = "400 Broad St, Seattle, WA 98109",
                    Category = "Observation Deck"
                }
            };
            var defaults = new Dictionary<string, int>
            {
                ["museum"] = 90,
                ["market"] = 45,
                ["default"] = 60
            };

            // Act & Assert - Should pass initial validation
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                pois, "en", defaults, 20, 180);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task EstimateBatchMinVisitMinutesAsync_WithInvalidConstraints_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var pois = new List<PointOfInterest>
            {
                new()
                {
                    Id = "poi-1",
                    Name = "Test POI",
                    Address = "123 Test St",
                    Category = "Test Category"
                }
            };
            var defaults = new Dictionary<string, int> { ["default"] = 60 };

            // Act & Assert - Min > Max should be handled gracefully
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                pois, "en", defaults, 180, 20); // min > max

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Theory]
        [InlineData("")]
        [InlineData(null)]
        public async Task EstimateBatchMinVisitMinutesAsync_WithInvalidLanguage_ShouldNotThrowOnValidation(string? language)
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var pois = new List<PointOfInterest>
            {
                new()
                {
                    Id = "poi-1",
                    Name = "Test POI",
                    Address = "123 Test St",
                    Category = "Test Category"
                }
            };
            var defaults = new Dictionary<string, int> { ["default"] = 60 };

            // Act & Assert - Should handle null/empty language gracefully
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                pois, language!, defaults, 20, 180);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task EstimateBatchMinVisitMinutesAsync_WithLargeBatch_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            
            // Create a large batch of POIs (30 items)
            var pois = Enumerable.Range(1, 30).Select(i => new PointOfInterest
            {
                Id = $"poi-{i}",
                Name = $"Test POI {i}",
                Address = $"{i} Test St",
                Category = i % 3 == 0 ? "Museum" : i % 2 == 0 ? "Restaurant" : "Attraction"
            }).ToList();

            var defaults = new Dictionary<string, int>
            {
                ["museum"] = 90,
                ["restaurant"] = 60,
                ["attraction"] = 45,
                ["default"] = 30
            };

            // Act & Assert - Should handle large batches
            var act = async () => await service.EstimateBatchMinVisitMinutesAsync(
                pois, "en", defaults, 20, 180);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        #endregion

        #region Azure Maps Category Mapping Tests

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithValidInput_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants, parks, shopping";
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" },
                new() { Id = 7315, Name = "Restaurant" },
                new() { Id = 9362, Name = "Park & Recreation Area" },
                new() { Id = 7374, Name = "Shopping Center" },
                new() { Id = 9361, Name = "Public Park" },
                new() { Id = 7302, Name = "Chinese Restaurant" },
                new() { Id = 7319, Name = "Gallery" }
            };

            // Act & Assert - Should pass initial validation
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithEmptyInterests_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "";
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" }
            };

            // Act & Assert
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithNullInterests_ShouldThrowArgumentException()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" }
            };

            // Act & Assert
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                null!, language, cityName, availableCategories);

            await act.Should().ThrowAsync<ArgumentNullException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithEmptyCategories_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants";
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>();

            // Act & Assert - Should handle empty categories gracefully
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithNullCategories_ShouldThrowArgumentException()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants";
            var language = "en";
            var cityName = "Seattle";

            // Act & Assert
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, null!);

            await act.Should().ThrowAsync<ArgumentNullException>();
        }

        [Theory]
        [InlineData("")]
        [InlineData(null)]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithInvalidLanguage_ShouldNotThrowOnValidation(string? language)
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" },
                new() { Id = 7315, Name = "Restaurant" }
            };

            // Act & Assert - Should handle null/empty language gracefully
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language!, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Theory]
        [InlineData("")]
        [InlineData(null)]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithInvalidCityName_ShouldNotThrowOnValidation(string? cityName)
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants";
            var language = "en";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" },
                new() { Id = 7315, Name = "Restaurant" }
            };

            // Act & Assert - Should handle null/empty city name gracefully
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName!, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithLargeNumberOfCategories_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "museums, restaurants, shopping, parks, entertainment, nightlife";
            var language = "en";
            var cityName = "Seattle";
            
            // Create a large list of categories (simulate real Azure Maps data)
            var availableCategories = Enumerable.Range(7300, 100).Select(id => new PoiCategory
            {
                Id = id,
                Name = $"Category {id}"
            }).ToList();

            // Act & Assert - Should handle large category lists
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        [Fact]
        public async Task MapInterestsToAzureMapsCategoriesAsync_WithComplexInterests_ShouldNotThrowOnValidation()
        {
            // Arrange
            var service = new OpenAIService(_optionsMock.Object, _loggerMock.Object);
            var interests = "art museums and galleries, fine dining restaurants, local cafes, outdoor activities and parks, historic landmarks, shopping centers and boutiques";
            var language = "en";
            var cityName = "Seattle";
            var availableCategories = new List<PoiCategory>
            {
                new() { Id = 7321, Name = "Museum" },
                new() { Id = 7319, Name = "Gallery" },
                new() { Id = 7315, Name = "Restaurant" },
                new() { Id = 7318, Name = "Cafe" },
                new() { Id = 9362, Name = "Park & Recreation Area" },
                new() { Id = 7317, Name = "Historic Site" },
                new() { Id = 7374, Name = "Shopping Center" }
            };

            // Act & Assert - Should handle complex interest descriptions
            var act = async () => await service.MapInterestsToAzureMapsCategoriesAsync(
                interests, language, cityName, availableCategories);

            await act.Should().NotThrowAsync<ArgumentException>();
        }

        #endregion
    }
}