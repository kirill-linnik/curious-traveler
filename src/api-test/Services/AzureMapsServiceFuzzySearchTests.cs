using System.Text.Json;
using CuriousTraveler.Api.Models;
using CuriousTraveler.Api.Models.AzureMaps;
using CuriousTraveler.Api.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace CuriousTraveler.Api.Tests.Services;

public class AzureMapsServiceFuzzySearchTests
{
    [Fact]
    public void TestFuzzySearchResponseDeserialization()
    {
        // This is a sample of the actual response structure from the logs
        var sampleFuzzyResponse = """
        {
          "summary": {
            "query": "restaurant eating place dining eating house eatery",
            "queryType": "NON_NEAR",
            "queryTime": 623,
            "numResults": 100,
            "offset": 0,
            "totalResults": 100,
            "fuzzyLevel": 1,
            "geoBias": {
              "lat": 59.437,
              "lon": 24.7536
            },
            "queryIntent": []
          },
          "results": [
            {
              "type": "POI",
              "id": "PC3m2lINvsR4xBL1wzIiEw",
              "score": 0.9719278216,
              "dist": 70.34073,
              "info": "search:ta:233007000007650-EE",
              "poi": {
                "name": "Caffeine",
                "categorySet": [{"id": 7315}],
                "url": "caffeine.ee/",
                "categories": ["restaurant"],
                "classifications": [
                  {
                    "code": "RESTAURANT",
                    "names": [{"nameLocale": "en-US", "name": "restaurant"}]
                  }
                ]
              },
              "address": {
                "streetNumber": "14",
                "streetName": "Vana-Viru",
                "municipalitySubdivision": "Kesklinn",
                "municipality": "Tallinn",
                "neighbourhood": "Vanalinn",
                "countrySubdivision": "Harju maakond",
                "countrySubdivisionName": "Harju maakond",
                "countrySubdivisionCode": "37",
                "postalCode": "10148",
                "countryCode": "EE",
                "country": "Eesti",
                "countryCodeISO3": "EST",
                "freeformAddress": "Vana-Viru 14, 10148 Kesklinn, Tallinn",
                "localName": "Tallinn"
              },
              "position": {
                "lat": 59.437142,
                "lon": 24.752388
              },
              "viewport": {
                "topLeftPoint": {"lat": 59.43804, "lon": 24.75062},
                "btmRightPoint": {"lat": 59.43624, "lon": 24.75416}
              },
              "entryPoints": [
                {
                  "type": "main",
                  "position": {"lat": 59.43729, "lon": 24.75245}
                }
              ]
            }
          ]
        }
        """;

        // Test deserialization with AzureMapsSearchResponse
        var searchResponse = JsonSerializer.Deserialize<AzureMapsSearchResponse>(sampleFuzzyResponse);
        
        Assert.NotNull(searchResponse);
        Assert.NotNull(searchResponse.Results);
        Assert.Single(searchResponse.Results);
        
        var result = searchResponse.Results.First();
        Assert.Equal("Caffeine", result.Poi?.Name);
        Assert.Equal(59.437142, result.Position?.Lat);
        Assert.Equal(24.752388, result.Position?.Lon);
        Assert.Contains("restaurant", result.Poi?.Categories ?? []);
    }

    [Fact]
    public void TestPoiCategorySearchResponseDeserialization()
    {
        // This is the structure returned by category search
        var sampleCategoryResponse = """
        {
          "summary": {
            "query": "7376 7315 7332",
            "queryType": "NON_NEAR",
            "queryTime": 223,
            "numResults": 0,
            "offset": 0,
            "totalResults": 0,
            "fuzzyLevel": 3,
            "geoBias": {
              "lat": 59.437,
              "lon": 24.7536
            }
          },
          "results": []
        }
        """;

        var searchResponse = JsonSerializer.Deserialize<AzureMapsSearchResponse>(sampleCategoryResponse);
        
        Assert.NotNull(searchResponse);
        Assert.NotNull(searchResponse.Results);
        Assert.Empty(searchResponse.Results);
    }

    [Fact]
    public void TestAzureMapsSearchResponseStructure()
    {
        // Check what properties AzureMapsSearchResponse actually has
        var response = new AzureMapsSearchResponse();
        
        // This should help us understand the structure
        var properties = typeof(AzureMapsSearchResponse).GetProperties();
        var resultProperty = properties.FirstOrDefault(p => p.Name == "Results");
        
        Assert.NotNull(resultProperty);
        
        // Check the result item type
        var resultType = typeof(AzureMapsSearchResult);
        var poiProperty = resultType.GetProperties().FirstOrDefault(p => p.Name == "Poi");
        var positionProperty = resultType.GetProperties().FirstOrDefault(p => p.Name == "Position");
        
        Assert.NotNull(poiProperty);
        Assert.NotNull(positionProperty);
    }
}