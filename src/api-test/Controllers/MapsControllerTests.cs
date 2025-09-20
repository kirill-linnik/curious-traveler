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
    public void GetTileProxy_ReturnsNotImplemented()
    {
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