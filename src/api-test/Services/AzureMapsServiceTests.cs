using CuriousTraveler.Api.Services;
using CuriousTraveler.Api.Models;
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
            
            _httpClient = new HttpClient(_httpMessageHandlerMock.Object);
            
            _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");
            _configMock.Setup(c => c["AZURE_MAPS_ACCOUNT_NAME"]).Returns("test-maps-account");
            
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
            configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");

            Assert.Throws<InvalidOperationException>(() => 
                new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, configMock.Object));
        }

        [Fact]
        public async Task GetAccessTokenAsync_AadMode_RequiresValidCredentials()
        {
            var service = new AzureMapsService(_httpClient, _cacheMock.Object, _loggerMock.Object, _configMock.Object);

            // In a test environment without valid Azure credentials, this should either:
            // 1. Throw an exception due to authentication failure, OR
            // 2. Return a token if credentials are available (like in CI/CD)
            // We'll test that the method doesn't hang or crash
            try
            {
                var token = await service.GetAccessTokenAsync();
                // If we get here, credentials were available - that's also valid
                token.Should().NotBeNull();
                token.AccessToken.Should().NotBeNullOrEmpty();
            }
            catch (Exception ex)
            {
                // Expected in environments without Azure credentials
                ex.Should().NotBeNull();
                // Common auth exceptions we expect in test environments
                (ex.GetType().Name.Contains("Credential") || 
                 ex.GetType().Name.Contains("Authentication") ||
                 ex.Message.Contains("credential") ||
                 ex.Message.Contains("authentication")).Should().BeTrue($"Expected auth-related exception, got: {ex.GetType().Name}: {ex.Message}");
            }
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
    }
}
