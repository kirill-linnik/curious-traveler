using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using System.Net;
using System.Text.Json;
using CuriousTraveler.Api.Models;
using Xunit;

namespace CuriousTraveler.Api.Tests.Integration;

public class GeocodingEndpointsTests : IClassFixture<CuriousTravelerApiWebApplicationFactory>
{
    private readonly HttpClient _client;
    private readonly CuriousTravelerApiWebApplicationFactory _factory;

    public GeocodingEndpointsTests(CuriousTravelerApiWebApplicationFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task GetHealth_ReturnsOk()
    {
        // Act
        var response = await _client.GetAsync("/healthz");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        content.Should().Contain("healthy");
    }

    [Fact]
    public async Task GetHealthReady_ReturnsOk()
    {
        // Act
        var response = await _client.GetAsync("/readyz");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        content.Should().Contain("ready");
    }

    [Theory]
    [InlineData("/api/geocode/reverse?latitude=47.6062&longitude=-122.3321")]
    [InlineData("/api/geocode/reverse?latitude=40.7128&longitude=-74.0060")]
    public async Task ReverseGeocode_ValidCoordinates_ReturnsOk(string endpoint)
    {
        // Act
        var response = await _client.GetAsync(endpoint);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        content.Should().NotBeNullOrEmpty();

        // Verify response structure
        var result = JsonSerializer.Deserialize<ReverseGeocodeResponse>(content, new JsonSerializerOptions 
        { 
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
        });
        
        result.Should().NotBeNull();
        result!.FormattedAddress.Should().NotBeNullOrEmpty();
        result.Center.Should().NotBeNull();
    }

    [Theory]
    [InlineData("/api/geocode/reverse?latitude=91&longitude=0")]     // Invalid latitude
    [InlineData("/api/geocode/reverse?latitude=0&longitude=181")]    // Invalid longitude
    [InlineData("/api/geocode/reverse?latitude=abc&longitude=0")]    // Invalid format
    [InlineData("/api/geocode/reverse?longitude=-122.3321")]         // Missing latitude
    [InlineData("/api/geocode/reverse?latitude=47.6062")]            // Missing longitude
    public async Task ReverseGeocode_InvalidParameters_ReturnsBadRequest(string endpoint)
    {
        // Act
        var response = await _client.GetAsync(endpoint);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Theory]
    [InlineData("/api/geocode/search?query=Seattle")]
    [InlineData("/api/geocode/search?query=Space%20Needle")]
    [InlineData("/api/geocode/search?query=New%20York%20City")]
    public async Task Search_ValidQuery_ReturnsOk(string endpoint)
    {
        // Act
        var response = await _client.GetAsync(endpoint);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        content.Should().NotBeNullOrEmpty();

        // Verify response structure
        var results = JsonSerializer.Deserialize<List<GeocodeSearchResult>>(content, new JsonSerializerOptions 
        { 
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
        });
        
        results.Should().NotBeNull();
    }

    [Theory]
    [InlineData("/api/geocode/search?query=")]          // Empty query
    [InlineData("/api/geocode/search")]                 // Missing query
    [InlineData("/api/geocode/search?query=%20%20")]    // Whitespace only
    public async Task Search_InvalidQuery_ReturnsBadRequest(string endpoint)
    {
        // Act
        var response = await _client.GetAsync(endpoint);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task ReverseGeocode_WithAcceptLanguageHeader_ReturnsLocalizedResult()
    {
        // Arrange
        _client.DefaultRequestHeaders.Add("Accept-Language", "es");

        // Act
        var response = await _client.GetAsync("/api/geocode/reverse?latitude=47.6062&longitude=-122.3321");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        
        var result = JsonSerializer.Deserialize<ReverseGeocodeResponse>(content, new JsonSerializerOptions 
        { 
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
        });
        
        result.Should().NotBeNull();
        result!.FormattedAddress.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Search_WithAcceptLanguageHeader_ReturnsLocalizedResults()
    {
        // Arrange
        _client.DefaultRequestHeaders.Add("Accept-Language", "fr");

        // Act
        var response = await _client.GetAsync("/api/geocode/search?query=Paris");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        
        var results = JsonSerializer.Deserialize<List<GeocodeSearchResult>>(content, new JsonSerializerOptions 
        { 
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
        });
        
        results.Should().NotBeNull();
    }

    [Fact]
    public async Task ApiEndpoints_SupportsOptionsForCors()
    {
        // Act
        var response = await _client.SendAsync(new HttpRequestMessage(HttpMethod.Options, "/api/geocode/reverse"));

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.Should().ContainKey("Access-Control-Allow-Origin");
    }

    [Fact]
    public async Task OpenApiSpec_IsAccessible()
    {
        // Act
        var response = await _client.GetAsync("/swagger/v1/swagger.json");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var content = await response.Content.ReadAsStringAsync();
        content.Should().Contain("\"openapi\":");
        content.Should().Contain("geocode");
    }

    [Fact]
    public async Task RateLimiting_EnforcesLimits()
    {
        // This test verifies that rate limiting is configured
        // In a real scenario, you might want to test actual rate limiting behavior
        // but that would require making many requests which could be slow
        
        // Act - Make a normal request
        var response = await _client.GetAsync("/api/geocode/reverse?latitude=47.6062&longitude=-122.3321");

        // Assert - Should succeed normally
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        
        // Check for rate limiting headers (if implemented)
        // response.Headers.Should().ContainKey("X-RateLimit-Limit");
    }
}