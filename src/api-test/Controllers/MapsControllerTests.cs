using CuriousTraveler.Api.Controllers;
using CuriousTraveler.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using FluentAssertions;
using Xunit;

namespace CuriousTraveler.Api.Tests.Controllers;

public class MapsControllerTests
{
    private readonly Mock<IAzureMapsService> _azureMapsServiceMock;
    private readonly Mock<ILogger<MapsController>> _loggerMock;
    private readonly Mock<IConfiguration> _configMock;
    private readonly MapsController _controller;

    public MapsControllerTests()
    {
        _azureMapsServiceMock = new Mock<IAzureMapsService>();
        _loggerMock = new Mock<ILogger<MapsController>>();
        _configMock = new Mock<IConfiguration>();
        _controller = new MapsController(_azureMapsServiceMock.Object, _loggerMock.Object, _configMock.Object);
        
        // Set up HttpContext for all tests
        _controller.ControllerContext = new Microsoft.AspNetCore.Mvc.ControllerContext
        {
            HttpContext = new Microsoft.AspNetCore.Http.DefaultHttpContext()
        };
    }

    [Fact]
    public async Task GetAccessToken_AadMode_ReturnsToken()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");
        
        var expectedToken = new AzureMapsToken
        {
            AccessToken = "test-token",
            ExpiresAt = DateTime.UtcNow.AddHours(1)
        };

        _azureMapsServiceMock
            .Setup(s => s.GetAccessTokenAsync())
            .ReturnsAsync(expectedToken);

        // Act
        var result = await _controller.GetAccessToken();

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = result as OkObjectResult;
        var response = okResult!.Value as MapsTokenResponse;
        
        response.Should().NotBeNull();
        response!.AccessToken.Should().Be("test-token");
        response.ExpiresIn.Should().BeGreaterThan(0);
        response.TokenType.Should().Be("Bearer");
    }

    [Fact]
    public async Task GetAccessToken_KeyMode_ReturnsBadRequest()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("KEY");

        // Act
        var result = await _controller.GetAccessToken();

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ProblemDetails>();
        
        var problemDetails = badRequestResult.Value as ProblemDetails;
        problemDetails!.Title.Should().Be("Access tokens not available");
    }

    [Fact]
    public async Task GetAccessToken_ServiceThrowsException_ReturnsBadRequest()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");
        
        _azureMapsServiceMock
            .Setup(s => s.GetAccessTokenAsync())
            .ThrowsAsync(new InvalidOperationException("Failed to get token"));

        // Act
        var result = await _controller.GetAccessToken();

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public async Task GetAccessToken_UnexpectedException_ReturnsServerError()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");
        
        _azureMapsServiceMock
            .Setup(s => s.GetAccessTokenAsync())
            .ThrowsAsync(new Exception("Unexpected error"));

        // Act
        var result = await _controller.GetAccessToken();

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = result as ObjectResult;
        objectResult!.StatusCode.Should().Be(502);
        objectResult.Value.Should().BeOfType<ProblemDetails>();
    }

    [Fact]
    public void GetTileProxy_AadMode_ReturnsBadRequest()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("AAD");

        // Act
        var result = _controller.GetTileProxy("test/tile/path");

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ProblemDetails>();
        
        var problemDetails = badRequestResult.Value as ProblemDetails;
        problemDetails!.Title.Should().Be("Tile proxy not available");
    }

    [Fact]
    public void GetTileProxy_KeyMode_ReturnsNotImplemented()
    {
        // Arrange
        _configMock.Setup(c => c["AZURE_MAPS_AUTH_MODE"]).Returns("KEY");

        // Act
        var result = _controller.GetTileProxy("test/tile/path");

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = result as ObjectResult;
        objectResult!.StatusCode.Should().Be(501);
        objectResult.Value.Should().BeOfType<ProblemDetails>();
        
        var problemDetails = objectResult.Value as ProblemDetails;
        problemDetails!.Title.Should().Be("Not implemented");
    }
}