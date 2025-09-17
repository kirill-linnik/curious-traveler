using CuriousTraveler.Api.Controllers;
using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using FluentAssertions;
using Xunit;

namespace CuriousTraveler.Api.Tests.Controllers;

public class GeocodingControllerTests
{
    private readonly Mock<IAzureMapsService> _azureMapsServiceMock;
    private readonly Mock<ILogger<GeocodingController>> _loggerMock;
    private readonly GeocodingController _controller;

    public GeocodingControllerTests()
    {
        _azureMapsServiceMock = new Mock<IAzureMapsService>();
        _loggerMock = new Mock<ILogger<GeocodingController>>();
        _controller = new GeocodingController(_azureMapsServiceMock.Object, _loggerMock.Object);
        
        // Set up HttpContext for all tests
        _controller.ControllerContext = new Microsoft.AspNetCore.Mvc.ControllerContext
        {
            HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext()
        };
    }

    [Fact]
    public async Task ReverseGeocode_ValidCoordinates_ReturnsOkResult()
    {
        // Arrange
        var latitude = 47.6062;
        var longitude = -122.3321;
        var expectedResult = new ReverseGeocodeResponse
        {
            FormattedAddress = "Seattle, WA, United States",
            Locality = "Seattle",
            CountryCode = "US",
            Center = new GeocodePosition { Latitude = latitude, Longitude = longitude }
        };

        _azureMapsServiceMock
            .Setup(s => s.ReverseGeocodeAsync(latitude, longitude, It.IsAny<string?>()))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.ReverseGeocode(latitude, longitude);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().BeEquivalentTo(expectedResult);
    }

    [Theory]
    [InlineData(-91, 0)]  // Invalid latitude
    [InlineData(91, 0)]   // Invalid latitude
    [InlineData(0, -181)] // Invalid longitude
    [InlineData(0, 181)]  // Invalid longitude
    public async Task ReverseGeocode_InvalidCoordinates_ReturnsBadRequest(double latitude, double longitude)
    {
        // Act
        var result = await _controller.ReverseGeocode(latitude, longitude);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public async Task ReverseGeocode_ServiceThrowsException_ReturnsInternalServerError()
    {
        // Arrange
        _azureMapsServiceMock
            .Setup(s => s.ReverseGeocodeAsync(It.IsAny<double>(), It.IsAny<double>(), It.IsAny<string?>()))
            .ThrowsAsync(new InvalidOperationException("Service error"));

        // Act
        var result = await _controller.ReverseGeocode(47.6062, -122.3321);

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = result as ObjectResult;
        objectResult!.StatusCode.Should().Be(500);
        objectResult.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public async Task Search_ValidQuery_ReturnsOkResult()
    {
        // Arrange
        var query = "Space Needle";
        var expectedResults = new List<GeocodeSearchResult>
        {
            new GeocodeSearchResult
            {
                Name = "Space Needle",
                Type = "POI",
                FormattedAddress = "400 Broad St, Seattle, WA 98109",
                Locality = "Seattle",
                CountryCode = "US",
                Position = new GeocodePosition { Latitude = 47.6205, Longitude = -122.3493 },
                Confidence = "High"
            }
        };

        _azureMapsServiceMock
            .Setup(s => s.SearchAsync(query, It.IsAny<string?>(), It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()))
            .ReturnsAsync(expectedResults);

        // Act
        var result = await _controller.SearchLocations(query);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        okResult!.Value.Should().BeEquivalentTo(expectedResults);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public async Task Search_EmptyOrNullQuery_ReturnsBadRequest(string? query)
    {
        // Act
        var result = await _controller.SearchLocations(query!);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public async Task Search_ServiceThrowsException_ReturnsInternalServerError()
    {
        // Arrange
        _azureMapsServiceMock
            .Setup(s => s.SearchAsync(It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()))
            .ThrowsAsync(new InvalidOperationException("Service error"));

        // Act
        var result = await _controller.SearchLocations("valid query");

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = result as ObjectResult;
        objectResult!.StatusCode.Should().Be(500);
        objectResult.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public async Task ReverseGeocode_WithLanguageHeader_PassesLanguageToService()
    {
        // Arrange
        var latitude = 47.6062;
        var longitude = -122.3321;
        var language = "es";

        var expectedResult = new ReverseGeocodeResponse
        {
            FormattedAddress = "Seattle, WA, Estados Unidos",
            Locality = "Seattle",
            CountryCode = "US",
            Center = new GeocodePosition { Latitude = latitude, Longitude = longitude }
        };

        _azureMapsServiceMock
            .Setup(s => s.ReverseGeocodeAsync(latitude, longitude, language))
            .ReturnsAsync(expectedResult);

        // Set up the controller context to simulate Accept-Language header
        _controller.ControllerContext.HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext();
        _controller.ControllerContext.HttpContext.Request.Headers["Accept-Language"] = language;

        // Act
        var result = await _controller.ReverseGeocode(latitude, longitude);

        // Assert
        _azureMapsServiceMock.Verify(s => s.ReverseGeocodeAsync(latitude, longitude, language), Times.Once);
        result.Should().BeOfType<OkObjectResult>();
    }

    [Fact]
    public async Task Search_WithLanguageHeader_PassesLanguageToService()
    {
        // Arrange
        var query = "Space Needle";
        var language = "es";

        var expectedResults = new List<GeocodeSearchResult>
        {
            new GeocodeSearchResult
            {
                Name = "Space Needle",
                Type = "POI",
                FormattedAddress = "400 Broad St, Seattle, WA 98109",
                Locality = "Seattle",
                CountryCode = "US",
                Position = new GeocodePosition { Latitude = 47.6205, Longitude = -122.3493 },
                Confidence = "High"
            }
        };

        _azureMapsServiceMock
            .Setup(s => s.SearchAsync(query, language, It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()))
            .ReturnsAsync(expectedResults);

        // Set up the controller context to simulate Accept-Language header
        _controller.ControllerContext.HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext();
        _controller.ControllerContext.HttpContext.Request.Headers["Accept-Language"] = language;

        // Act
        var result = await _controller.SearchLocations(query);

        // Assert
        _azureMapsServiceMock.Verify(s => s.SearchAsync(query, language, It.IsAny<double?>(), It.IsAny<double?>(), It.IsAny<int>()), Times.Once);
        result.Should().BeOfType<OkObjectResult>();
    }
}