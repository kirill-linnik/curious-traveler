using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Models.Itinerary;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Moq.Protected;
using System.Net;
using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace CuriousTraveler.Api.Tests.Services
{
    public class AzureMapsServiceTests : IDisposable
    {
        private readonly Mock<ILogger<AzureMapsService>> _loggerMock;
        private readonly Mock<IMemoryCache> _cacheMock;
        private readonly Mock<IConfiguration> _configMock;
        private readonly Mock<HttpMessageHandler> _httpMessageHandlerMock;
        private readonly HttpClient _httpClient;

        public AzureMapsServiceTests()
        {
            _loggerMock = new Mock<ILogger<AzureMapsService>>();
            _cacheMock = new Mock<IMemoryCache>();
            _configMock = new Mock<IConfiguration>();
            _httpMessageHandlerMock = new Mock<HttpMessageHandler>();
            
            // Setup configuration for AzureMaps with subscription key authentication
            _configMock.Setup(c => c["AzureMaps:AccountName"]).Returns("test-account");
            _configMock.Setup(c => c["AzureMaps:SubscriptionKey"]).Returns("test-subscription-key");
            
            _httpClient = new HttpClient(_httpMessageHandlerMock.Object);
            
            _cacheMock.Setup(c => c.CreateEntry(It.IsAny<object>()))
                      .Returns<object>((key) => 
                      {
                          var mockCacheEntry = new Mock<ICacheEntry>();
                          mockCacheEntry.SetupGet(e => e.Key).Returns(key);
                          mockCacheEntry.SetupProperty(e => e.Value);
                          mockCacheEntry.SetupProperty(e => e.AbsoluteExpirationRelativeToNow);
                          return mockCacheEntry.Object;
                      });
            
            _cacheMock.Setup(c => c.TryGetValue(It.IsAny<object>(), out It.Ref<object?>.IsAny))
                      .Returns(false);
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }

        [Fact]
        public void Constructor_MissingAccountName_ThrowsInvalidOperationException()
        {
            var configMock = new Mock<IConfiguration>();
            configMock.Setup(c => c["AzureMaps:SubscriptionKey"]).Returns("test-key");

            Assert.Throws<InvalidOperationException>(() => 
                new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, configMock.Object));
        }

        [Fact]
        public void Constructor_MissingSubscriptionKey_ThrowsInvalidOperationException()
        {
            var configMock = new Mock<IConfiguration>();
            configMock.Setup(c => c["AzureMaps:AccountName"]).Returns("test-account");

            Assert.Throws<InvalidOperationException>(() => 
                new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, configMock.Object));
        }

        [Fact]
        public async Task GetAccessTokenAsync_ReturnsEmptyToken()
        {
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            var token = await service.GetAccessTokenAsync();
            
            token.Should().NotBeNull();
            token.AccessToken.Should().BeEmpty();
            token.ExpiresAt.Should().BeAfter(DateTime.UtcNow);
        }

        [Theory]
        [InlineData("")]
        [InlineData("   ")]
        [InlineData(null)]
        public async Task SearchAsync_EmptyQuery_ReturnsEmptyResults(string? query)
        {
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);
            var results = await service.SearchAsync(query!);
            results.Should().NotBeNull().And.BeEmpty();
        }

        [Fact]
        public async Task SearchPoisAsync_WithValidParameters_ShouldReturnResults()
        {
            // Arrange
            var mockResponse = new
            {
                results = new[]
                {
                    new
                    {
                        poi = new { name = "Test Museum" },
                        address = new { freeformAddress = "123 Test St" },
                        position = new { lat = 47.6062, lon = -122.3321 },
                        categories = new[] { "Museum" }
                    }
                }
            };

            var jsonResponse = JsonSerializer.Serialize(mockResponse);
            var mockHttpResponse = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(jsonResponse, System.Text.Encoding.UTF8, "application/json")
            };

            _httpMessageHandlerMock.Protected()
                .Setup<Task<HttpResponseMessage>>(
                    "SendAsync",
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>())
                .ReturnsAsync(mockHttpResponse);

            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act
            var center = new LocationPoint { Lat = 47.6062, Lon = -122.3321 };
            var results = await service.SearchPoisAsync(
                center,
                new List<int> { 7321 }, // Museum category
                10.0, // 10km radius
                10); // 10 results per category

            // Assert
            results.Should().NotBeNull();
            results.Should().HaveCount(1);
            results.First().Name.Should().Be("Test Museum");
        }

        [Fact]
        public async Task SearchPoisAsync_WithEmptyCategoryIds_ShouldReturnEmpty()
        {
            // Arrange
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act
            var center = new LocationPoint { Lat = 47.6062, Lon = -122.3321 };
            var results = await service.SearchPoisAsync(
                center,
                new List<int>(), // Empty category list
                10.0,
                10);

            // Assert
            results.Should().NotBeNull().And.BeEmpty();
        }

        [Fact]
        public async Task SearchPoisAsync_WithMultipleCategories_ShouldMakeMultipleApiCalls()
        {
            // Arrange
            var mockResponse = new
            {
                results = new[]
                {
                    new
                    {
                        poi = new { name = "Test POI" },
                        address = new { freeformAddress = "123 Test St" },
                        position = new { lat = 47.6062, lon = -122.3321 },
                        categories = new[] { "Test Category" }
                    }
                }
            };

            var jsonResponse = JsonSerializer.Serialize(mockResponse);
            var mockHttpResponse = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(jsonResponse, System.Text.Encoding.UTF8, "application/json")
            };

            _httpMessageHandlerMock.Protected()
                .Setup<Task<HttpResponseMessage>>(
                    "SendAsync",
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>())
                .ReturnsAsync(mockHttpResponse);

            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act
            var center = new LocationPoint { Lat = 47.6062, Lon = -122.3321 };
            var results = await service.SearchPoisAsync(
                center,
                new List<int> { 7321, 7315, 7374 }, // Multiple categories
                10.0,
                10);

            // Assert - Should make 3 API calls (one per category)
            _httpMessageHandlerMock.Protected()
                .Verify<Task<HttpResponseMessage>>(
                    "SendAsync",
                    Times.Exactly(3),
                    ItExpr.IsAny<HttpRequestMessage>(),
                    ItExpr.IsAny<CancellationToken>());

            results.Should().NotBeNull();
            // Should return up to 30 results (10 per category * 3 categories)
            results.Should().HaveCountLessOrEqualTo(30);
        }

        [Fact]
        public async Task SearchPoisAsync_WithZeroLimit_ShouldReturnEmpty()
        {
            // Arrange
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act
            var center = new LocationPoint { Lat = 47.6062, Lon = -122.3321 };
            var results = await service.SearchPoisAsync(
                center,
                new List<int> { 7321 },
                10.0,
                0); // Zero limit

            // Assert
            results.Should().NotBeNull().And.BeEmpty();
        }

        [Fact]
        public async Task SearchPoisAsync_WithNullCenter_ShouldThrowNullReferenceException()
        {
            // Arrange
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act & Assert - The actual service throws NullReferenceException when accessing center.Lat/Lon
            await Assert.ThrowsAsync<NullReferenceException>(() =>
                service.SearchPoisAsync(
                    null!,
                    new List<int> { 7321 },
                    10.0,
                    10));
        }

        [Fact]
        public async Task SearchPoisAsync_WithNullCategoryIds_ShouldReturnEmpty()
        {
            // Arrange
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // Act - The service handles null categoryIds by checking if any exist
            var center = new LocationPoint { Lat = 47.6062, Lon = -122.3321 };
            var results = await service.SearchPoisAsync(
                center,
                null!,
                10.0,
                10);

            // Assert - Service should handle gracefully and return empty result
            results.Should().NotBeNull().And.BeEmpty();
        }
    }
}
