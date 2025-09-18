using CuriousTraveler.Api.Models.Configuration;
using CuriousTraveler.Api.Models.Itinerary;
using CuriousTraveler.Api.Services.AI;
using Microsoft.Extensions.Options;
using System.Globalization;

namespace CuriousTraveler.Api.Services.Business;

public interface IItineraryBuilderService
{
    Task<ItineraryResult> BuildItineraryAsync(
        ItineraryRequest request, 
        CancellationToken cancellationToken = default);
}

public class ItineraryBuilderService : IItineraryBuilderService
{
    private readonly IAzureMapsService _mapsService;
    private readonly IOpenAIService _openAIService;
    private readonly ItinerariesOptions _options;
    private readonly ILogger<ItineraryBuilderService> _logger;

    public ItineraryBuilderService(
        IAzureMapsService mapsService,
        IOpenAIService openAIService,
        IOptions<ItinerariesOptions> options,
        ILogger<ItineraryBuilderService> logger)
    {
        _mapsService = mapsService;
        _openAIService = openAIService;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<ItineraryResult> BuildItineraryAsync(
        ItineraryRequest request,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Building itinerary from ({StartLat},{StartLon}) to ({EndLat},{EndLon})",
            request.Start.Lat, request.Start.Lon, request.End.Lat, request.End.Lon);

        _logger.LogDebug("DEBUG: Step 1 - Getting timezone for start location");
        // Step 1: Validate inputs and determine local time
        var timeZone = await _mapsService.GetTimeZoneAsync(request.Start.Lat, request.Start.Lon);
        var startTimeLocal = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, timeZone);
        _logger.LogDebug("DEBUG: Step 1 - Timezone: {TimeZone}, Local start time: {StartTime}", 
            timeZone.Id, startTimeLocal);

        _logger.LogDebug("DEBUG: Step 2 - Checking commute feasibility");
        // Step 2: Check commute feasibility
        var baseRoute = await _mapsService.GetRouteAsync(request.Start, request.End, request.Mode);
        _logger.LogDebug("DEBUG: Step 2 - Base route: {TravelTime} minutes, round trip: {RoundTrip} minutes vs budget: {Budget} minutes",
            baseRoute.TravelTimeMinutes, baseRoute.TravelTimeMinutes * 2, request.MaxDurationMinutes);
        if (baseRoute.TravelTimeMinutes * 2 > request.MaxDurationMinutes) // Round trip
        {
            throw new InvalidOperationException($"COMMUTE_EXCEEDS_BUDGET: Base commute requires {baseRoute.TravelTimeMinutes * 2} minutes, exceeds budget of {request.MaxDurationMinutes}");
        }

        _logger.LogDebug("DEBUG: Step 3 - Checking transit availability");
        // Step 3: Check transit availability if needed
        if (request.Mode == TravelMode.PublicTransport)
        {
            _logger.LogDebug("DEBUG: Step 3 - Checking transit availability for public transport mode");
            var transitAvailable = await _mapsService.IsTransitAvailableAsync(request.Start);
            _logger.LogDebug("DEBUG: Step 3 - Transit available: {Available}", transitAvailable);
            if (!transitAvailable)
            {
                _logger.LogWarning("Transit not available, using walking fallback");
                // Could implement fallback logic here
            }
        }

        _logger.LogDebug("DEBUG: Step 4 - Determining reachability area");
        // Step 4: Determine reachability area
        var reachabilityCenter = GetReachabilityCenter(request.Start, request.End);
        var availableTime = request.MaxDurationMinutes - (baseRoute.TravelTimeMinutes * 2);
        var exploreTime = Math.Max(30, availableTime); // Use all available time for exploration
        _logger.LogDebug("DEBUG: Step 4 - Reachability center: ({Lat},{Lon}), available time: {Available} min, explore time: {Explore} min",
            reachabilityCenter.Lat, reachabilityCenter.Lon, availableTime, exploreTime);

        IsochroneResult? isochrone = null;
        double searchRadius = _options.DefaultRadiusKm.GetValueOrDefault(request.Mode.ToString().ToLowerInvariant(), 2.5);

        _logger.LogDebug("DEBUG: Getting isochrone for reachability analysis");
        _logger.LogDebug("DEBUG: UseIsochroneIfAvailable: {UseIsochrone}, exploreTime: {ExploreTime} min", 
            _options.UseIsochroneIfAvailable, exploreTime);
        if (_options.UseIsochroneIfAvailable)
        {
            isochrone = await _mapsService.GetIsochroneAsync(reachabilityCenter, request.Mode, exploreTime);
            _logger.LogDebug("DEBUG: Isochrone result: {Available}", isochrone != null ? "Available" : "Not available");
        }

        if (isochrone == null)
        {
            // Calculate radius based on speed × time instead of using fixed default
            var speed = _options.AvgSpeedsKmh.GetValueOrDefault(request.Mode.ToString().ToLowerInvariant(), 4.5);
            var calculatedRadius = (speed * exploreTime) / 60.0; // Convert minutes to hours
            searchRadius = Math.Max(calculatedRadius, 1.0); // Minimum 1km radius
            
            _logger.LogInformation("Using calculated radius fallback: {Radius:F1} km (speed: {Speed} km/h × time: {Time} min)", 
                searchRadius, speed, exploreTime);
        }

        _logger.LogDebug("DEBUG: Step 5 - Mapping interests to categories");
        _logger.LogDebug("DEBUG: Step 5 - Interests: {Interests}", request.Interests);
        
        // Step 5: Get Azure Maps category tree and map interests
        var availableCategories = await _mapsService.GetPoiCategoryTreeAsync(request.Language);
        _logger.LogDebug("DEBUG: Step 5 - Loaded {Count} categories from Azure Maps", availableCategories.Count);
        
        var azureMapsCategories = await _openAIService.MapInterestsToAzureMapsCategoriesAsync(
            request.Interests,
            request.Language,
            "Unknown City", // Could geocode to get city name
            availableCategories,
            cancellationToken);

        _logger.LogDebug("DEBUG: Step 5 - AI mapped to {Count} Azure Maps categories: {Categories}", 
            azureMapsCategories.Count, string.Join(", ", azureMapsCategories));

        if (!azureMapsCategories.Any())
        {
            throw new InvalidOperationException("NO_POIS_IN_ISOCHRONE: No matching Azure Maps categories found for interests");
        }

        _logger.LogDebug("DEBUG: Step 6 - Searching for POIs");
        _logger.LogDebug("DEBUG: Step 6 - Search center: ({Lat},{Lon}), radius: {Radius} km",
            reachabilityCenter.Lat, reachabilityCenter.Lon, searchRadius);
        
        // Step 6: Search for POIs per category with individual fallbacks
        var candidatePois = new List<PointOfInterest>();
        var maxPoisPerCategory = 10; // Up to 10 POIs per category
        
        // Get category names for fuzzy fallback
        var matchedCategories = availableCategories
            .Where(c => azureMapsCategories.Contains(c.IdString))
            .ToList();
        
        _logger.LogDebug("DEBUG: Step 6 - Performing separate searches for {Count} categories", azureMapsCategories.Count);
        
        for (int i = 0; i < azureMapsCategories.Count; i++)
        {
            var categoryId = azureMapsCategories[i];
            var categoryPois = new List<PointOfInterest>();
            
            try
            {
                _logger.LogDebug("DEBUG: Step 6 - Searching category: {CategoryId}", categoryId);
                
                categoryPois = await _mapsService.SearchPoisAsync(
                    reachabilityCenter,
                    new List<string> { categoryId }, // Single category per search
                    searchRadius,
                    limit: maxPoisPerCategory);
                
                _logger.LogDebug("DEBUG: Step 6 - Category {CategoryId} returned {Count} POIs", categoryId, categoryPois.Count);
                
                // If category search returned no results, try fuzzy search for this specific category
                if (!categoryPois.Any() && i < matchedCategories.Count)
                {
                    var categoryName = matchedCategories[i].Name;
                    _logger.LogDebug("DEBUG: Step 6 - Category {CategoryId} ({CategoryName}) returned 0 results, trying fuzzy fallback", 
                        categoryId, categoryName);
                    
                    try
                    {
                        categoryPois = await _mapsService.SearchPoisFuzzyAsync(
                            reachabilityCenter,
                            new List<string> { categoryName },
                            searchRadius,
                            limit: maxPoisPerCategory);
                        
                        _logger.LogDebug("DEBUG: Step 6 - Fuzzy fallback for {CategoryName} returned {Count} POIs", 
                            categoryName, categoryPois.Count);
                    }
                    catch (Exception fuzzyEx)
                    {
                        _logger.LogWarning(fuzzyEx, "Fuzzy fallback failed for category {CategoryName}", categoryName);
                    }
                }
                
                candidatePois.AddRange(categoryPois);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to search for category {CategoryId}, continuing with other categories", categoryId);
            }
        }
        
        // Remove duplicates based on POI ID
        candidatePois = candidatePois
            .GroupBy(p => p.Id)
            .Select(g => g.First())
            .ToList();

        _logger.LogDebug("DEBUG: Step 6 - Combined results: {Count} unique candidate POIs from {CategoryCount} categories", 
            candidatePois.Count, azureMapsCategories.Count);

        if (!candidatePois.Any())
        {
            _logger.LogWarning("All category searches (including fuzzy fallbacks) returned 0 results. Trying final fallback with original interest terms.");
            
            // Final fallback: Try fuzzy search with original interest terms as last resort
            var fallbackTerms = request.Interests.Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(i => i.Trim())
                .Take(3) // Limit to 3 terms to avoid overwhelming the search
                .ToList();
            
            if (fallbackTerms.Any())
            {
                _logger.LogDebug("DEBUG: Step 6 - Final fuzzy fallback with interests: {Terms}", string.Join(", ", fallbackTerms));
                
                try
                {
                    candidatePois = await _mapsService.SearchPoisFuzzyAsync(
                        reachabilityCenter,
                        fallbackTerms,
                        searchRadius,
                        limit: 25);
                        
                    _logger.LogDebug("DEBUG: Step 6 - Final fuzzy fallback found {Count} candidate POIs", candidatePois.Count);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Final fuzzy fallback failed completely");
                }
            }
        }

        if (!candidatePois.Any())
        {
            throw new InvalidOperationException("NO_POIS_IN_ISOCHRONE: No POIs found in search area");
        }

        // Filter by isochrone if available
        if (isochrone != null)
        {
            candidatePois = FilterPoisByIsochrone(candidatePois, isochrone);
        }

        // Step 7: Estimate dwell times
        var dwellDefaults = new Dictionary<string, int>
        {
            ["museum"] = 90,
            ["landmark"] = 30,
            ["park"] = 45,
            ["gallery"] = 60,
            ["food"] = 30,
            ["cafe"] = 30,
            ["church"] = 30,
            ["default"] = 30
        };

        _logger.LogDebug("DEBUG: Step 7 - Estimating dwell times for {Count} POIs", candidatePois.Count);
        foreach (var poi in candidatePois)
        {
            poi.EstimatedMinVisitMinutes = await _openAIService.EstimateMinVisitMinutesAsync(
                poi, request.Language, dwellDefaults, 20, 180, cancellationToken);
        }
        _logger.LogDebug("DEBUG: Step 7 - Completed dwell time estimation");

        // Step 8: Filter by opening hours if strict mode enabled
        if (_options.StrictOpeningHours)
        {
            candidatePois = FilterByOpeningHours(candidatePois, startTimeLocal, availableTime);
        }

        if (!candidatePois.Any())
        {
            throw new InvalidOperationException("NO_OPEN_POIS: No POIs are open during the travel window");
        }

        _logger.LogDebug("DEBUG: Step 9 - Reranking POIs using Azure OpenAI");
        // Step 9: Rerank POIs
        var interests = request.Interests.Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(i => i.Trim()).ToList();

        _logger.LogDebug("DEBUG: Step 9 - Calling OpenAI reranking with {Count} POIs and interests: {Interests}", 
            candidatePois.Count, string.Join(", ", interests));
        var rankedPoiIds = await _openAIService.RerankPoisAsync(
            candidatePois,
            interests,
            request.Language,
            request.Mode,
            _options.MaxPois,
            request.MaxDurationMinutes,
            cancellationToken);

        _logger.LogDebug("DEBUG: Step 9 - OpenAI returned {Count} ranked POI IDs", rankedPoiIds.Count);

        _logger.LogDebug("DEBUG: Step 9.5 - Enforcing programmatic balance");
        // Step 9.5: Enforce balance programmatically in case AI prompts failed
        rankedPoiIds = EnforceInterestBalance(candidatePois, rankedPoiIds, interests);
        _logger.LogDebug("DEBUG: Step 9.5 - After balance enforcement: {Count} ranked POI IDs", rankedPoiIds.Count);

        _logger.LogDebug("DEBUG: Step 10 - Building greedy itinerary");
        // Step 10: Greedy itinerary construction
        var selectedPois = BuildGreedyItinerary(
            candidatePois,
            rankedPoiIds,
            request,
            baseRoute,
            availableTime);

        _logger.LogDebug("DEBUG: Step 10 - Selected {Count} POIs for itinerary", selectedPois.Count);

        if (!selectedPois.Any())
        {
            throw new InvalidOperationException("NO_OPEN_POIS: Could not fit any POIs within time budget");
        }

        // Step 10.5: Validate interest coverage
        _logger.LogDebug("DEBUG: Step 10.5 - Validating interest coverage");
        ValidateInterestCoverage(selectedPois, interests);

        _logger.LogDebug("DEBUG: Step 11 - Generating localized descriptions");
        // Step 11: Generate descriptions
        // Get city name from reverse geocoding
        var cityName = "Unknown City";
        try
        {
            var location = await _mapsService.ReverseGeocodeAsync(request.Start.Lat, request.Start.Lon, request.Language);
            cityName = location.Locality ?? location.FormattedAddress ?? "Unknown City";
            _logger.LogDebug("DEBUG: Step 11 - Detected city: {CityName}", cityName);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to get city name, using fallback");
        }
        
        var descriptions = await _openAIService.GenerateLocalizedDescriptionsAsync(
            selectedPois,
            request.Language,
            cityName,
            cancellationToken);

        _logger.LogDebug("DEBUG: Step 11 - Generated {Count} localized descriptions", descriptions.Count);

        _logger.LogDebug("DEBUG: Step 12 - Building final itinerary");
        // Step 12: Build final itinerary
        return await BuildFinalItinerary(
            request,
            selectedPois,
            descriptions,
            startTimeLocal,
            timeZone);
    }

    private static LocationPoint GetReachabilityCenter(LocationPoint start, LocationPoint end)
    {
        // Use midpoint between start and end as exploration center
        return new LocationPoint
        {
            Lat = (start.Lat + end.Lat) / 2,
            Lon = (start.Lon + end.Lon) / 2
        };
    }

    private static List<PointOfInterest> FilterPoisByIsochrone(
        List<PointOfInterest> pois,
        IsochroneResult isochrone)
    {
        // Simple point-in-polygon check (could be more sophisticated)
        return pois.Where(poi => IsPointInPolygon(
            poi.Latitude, poi.Longitude, isochrone.Boundary)).ToList();
    }

    private static bool IsPointInPolygon(double lat, double lon, List<LocationPoint> polygon)
    {
        // Simple ray casting algorithm
        bool inside = false;
        int j = polygon.Count - 1;

        for (int i = 0; i < polygon.Count; i++)
        {
            double xi = polygon[i].Lat, yi = polygon[i].Lon;
            double xj = polygon[j].Lat, yj = polygon[j].Lon;

            if (((yi > lon) != (yj > lon)) &&
                (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi))
            {
                inside = !inside;
            }
            j = i;
        }

        return inside;
    }

    private static List<PointOfInterest> FilterByOpeningHours(
        List<PointOfInterest> pois,
        DateTime startTime,
        int availableMinutes)
    {
        var endTime = startTime.AddMinutes(availableMinutes);
        
        return pois.Where(poi =>
        {
            // If no opening hours data, assume open
            if (poi.OpeningHours == null) return true;

            // Check if POI is open during any part of the visit window
            var visitStart = startTime.AddMinutes(30); // Assume 30 min to reach first POI
            var visitEnd = visitStart.AddMinutes(poi.EstimatedMinVisitMinutes);

            return poi.IsOpenAt(visitStart) && poi.IsOpenAt(visitEnd);
        }).ToList();
    }

    private List<PointOfInterest> BuildGreedyItinerary(
        List<PointOfInterest> candidates,
        List<string> rankedPoiIds,
        ItineraryRequest request,
        RouteResult baseRoute,
        int availableMinutes)
    {
        var selected = new List<PointOfInterest>();
        var totalTime = baseRoute.TravelTimeMinutes * 2; // Round trip base cost
        var currentLocation = request.Start;

        foreach (var poiId in rankedPoiIds.Take(_options.MaxPois))
        {
            var poi = candidates.FirstOrDefault(p => p.Id == poiId);
            if (poi == null) continue;

            var poiLocation = new LocationPoint { Lat = poi.Latitude, Lon = poi.Longitude };
            
            // Calculate time to get to this POI
            var routeToPoi = _mapsService.GetRouteAsync(currentLocation, poiLocation, request.Mode).Result;
            var timeToEnd = _mapsService.GetRouteAsync(poiLocation, request.End, request.Mode).Result;
            
            var additionalTime = routeToPoi.TravelTimeMinutes + poi.EstimatedMinVisitMinutes;
            
            // Update total if this would be the last POI
            var projectedTotal = totalTime - (selected.Any() ? 
                _mapsService.GetRouteAsync(currentLocation, request.End, request.Mode).Result.TravelTimeMinutes : 0) +
                additionalTime + timeToEnd.TravelTimeMinutes;

            if (projectedTotal <= request.MaxDurationMinutes)
            {
                selected.Add(poi);
                totalTime = projectedTotal - timeToEnd.TravelTimeMinutes + 
                    _mapsService.GetRouteAsync(poiLocation, request.End, request.Mode).Result.TravelTimeMinutes;
                currentLocation = poiLocation;
                
                _logger.LogDebug("Added POI {PoiName}, total time now {TotalTime} minutes", 
                    poi.Name, totalTime);
            }
            else
            {
                _logger.LogDebug("Skipped POI {PoiName}, would exceed budget ({ProjectedTotal} > {Budget})", 
                    poi.Name, projectedTotal, request.MaxDurationMinutes);
            }
        }

        // Redistribute slack time if available
        var remainingTime = request.MaxDurationMinutes - totalTime;
        if (remainingTime > 0 && selected.Any())
        {
            var additionalTimePerPoi = remainingTime / selected.Count;
            foreach (var poi in selected)
            {
                poi.EstimatedMinVisitMinutes += additionalTimePerPoi;
                // Re-check opening hours after extending time
            }
        }

        return selected;
    }

    private async Task<ItineraryResult> BuildFinalItinerary(
        ItineraryRequest request,
        List<PointOfInterest> selectedPois,
        Dictionary<string, string> descriptions,
        DateTime startTimeLocal,
        TimeZoneInfo timeZone)
    {
        var legs = new List<ItineraryLeg>();
        var stops = new List<ItineraryStop>();
        var currentMinutes = 0; // Minutes from journey start
        var currentLocation = request.Start;
        
        var totalDistance = 0;
        var totalTravelTime = 0;
        var totalVisitTime = selectedPois.Sum(p => p.EstimatedMinVisitMinutes);

        // Create legs and stops
        for (int i = 0; i < selectedPois.Count; i++)
        {
            var poi = selectedPois[i];
            var poiLocation = new LocationPoint { Lat = poi.Latitude, Lon = poi.Longitude };
            
            // Leg to POI
            var route = await _mapsService.GetRouteAsync(currentLocation, poiLocation, request.Mode);
            
            _logger.LogDebug("DEBUG: Route to {POI}: distance={Distance}m, travel={Travel}min, currentMinutes={Current}", 
                poi.Name, route.DistanceMeters, route.TravelTimeMinutes, currentMinutes);
            
            var legFrom = i == 0 ? "Start" : selectedPois[i - 1].Name;
            legs.Add(new ItineraryLeg
            {
                From = legFrom,
                To = poi.Name,
                Mode = request.Mode,
                DistanceMeters = route.DistanceMeters,
                TravelMinutes = route.TravelTimeMinutes,
                DepartFromJourneyStart = currentMinutes,
                ArriveFromJourneyStart = currentMinutes + route.TravelTimeMinutes
            });

            totalDistance += route.DistanceMeters;
            totalTravelTime += route.TravelTimeMinutes;
            currentMinutes += route.TravelTimeMinutes;

            _logger.LogDebug("DEBUG: After travel to {POI}: currentMinutes={Current}, visitTime={Visit}", 
                poi.Name, currentMinutes, poi.EstimatedMinVisitMinutes);

            // Stop at POI
            stops.Add(new ItineraryStop
            {
                Id = poi.Id,
                Name = poi.Name,
                Address = poi.Address,
                Lat = poi.Latitude,
                Lon = poi.Longitude,
                Description = descriptions.GetValueOrDefault(poi.Id, poi.Description ?? ""),
                VisitMinutes = poi.EstimatedMinVisitMinutes,
                ArriveFromJourneyStart = currentMinutes,
                DepartFromJourneyStart = currentMinutes + poi.EstimatedMinVisitMinutes,
                Category = poi.Category,
                Rating = poi.Rating
            });

            currentMinutes += poi.EstimatedMinVisitMinutes;
            _logger.LogDebug("DEBUG: After visiting {POI}: currentMinutes={Current}", poi.Name, currentMinutes);
            currentLocation = poiLocation;
        }

        // Final leg to end
        var finalRoute = await _mapsService.GetRouteAsync(currentLocation, request.End, request.Mode);
        legs.Add(new ItineraryLeg
        {
            From = selectedPois.Last().Name,
            To = "End",
            Mode = request.Mode,
            DistanceMeters = finalRoute.DistanceMeters,
            TravelMinutes = finalRoute.TravelTimeMinutes,
            DepartFromJourneyStart = currentMinutes,
            ArriveFromJourneyStart = currentMinutes + finalRoute.TravelTimeMinutes
        });

        totalDistance += finalRoute.DistanceMeters;
        totalTravelTime += finalRoute.TravelTimeMinutes;

        return new ItineraryResult
        {
            Summary = new ItinerarySummary
            {
                Mode = request.Mode,
                Language = request.Language,
                TimeBudgetMinutes = request.MaxDurationMinutes,
                TotalDistanceMeters = totalDistance,
                TotalTravelMinutes = totalTravelTime,
                TotalVisitMinutes = totalVisitTime,
                StopsCount = selectedPois.Count
            },
            Legs = legs,
            Stops = stops
        };
    }

    private void ValidateInterestCoverage(List<PointOfInterest> selectedPois, List<string> interests)
    {
        if (interests.Count <= 1) return; // No diversity validation needed for single interest
        
        var selectedCategories = selectedPois.Select(p => p.Category?.ToLowerInvariant()).Where(c => c != null).ToList();
        var foodCategories = new[] { "restaurant", "cafe", "food", "japanese", "chinese", "italian", "bar", "pub" };
        var culturalCategories = new[] { "museum", "gallery", "historic", "monument", "landmark", "church", "cathedral", "temple", "building" };
        
        var foodCount = selectedCategories.Count(c => foodCategories.Any(f => c!.Contains(f)));
        var culturalCount = selectedCategories.Count(c => culturalCategories.Any(cult => c!.Contains(cult)));
        
        var interestLower = interests.Select(i => i.ToLowerInvariant()).ToList();
        var hasFood = interestLower.Any(i => i.Contains("food") || i.Contains("restaurant") || i.Contains("dining"));
        var hasCultural = interestLower.Any(i => i.Contains("museum") || i.Contains("historic") || i.Contains("cultural") || i.Contains("monument"));
        
        _logger.LogDebug("DEBUG: Interest coverage - Food POIs: {FoodCount}, Cultural POIs: {CultureCount}", foodCount, culturalCount);
        _logger.LogDebug("DEBUG: User requested - Food: {HasFood}, Cultural: {HasCultural}", hasFood, hasCultural);
        _logger.LogDebug("DEBUG: Selected categories: {Categories}", string.Join(", ", selectedCategories));
        
        // Log serious warnings for missing interest coverage
        if (hasFood && foodCount == 0)
        {
            _logger.LogError("CRITICAL: User requested FOOD but NO food POIs selected! This violates user expectations.");
        }
        
        if (hasCultural && culturalCount == 0)
        {
            _logger.LogError("CRITICAL: User requested CULTURAL sites but NO cultural POIs selected! This violates user expectations.");
        }
        
        if (foodCount > 2)
        {
            _logger.LogWarning("WARNING: Too many food POIs selected ({Count}). Consider better diversity.", foodCount);
        }
        
        // Log success when coverage is good
        if (hasFood && hasCultural && foodCount > 0 && culturalCount > 0)
        {
            _logger.LogInformation("SUCCESS: Good interest coverage - Food: {FoodCount}, Cultural: {CultureCount}", foodCount, culturalCount);
        }
    }

    private List<string> EnforceInterestBalance(
        List<PointOfInterest> candidatePois, 
        List<string> aiRankedIds, 
        List<string> interests)
    {
        if (interests.Count <= 1) 
        {
            _logger.LogDebug("Single interest - no balance enforcement needed");
            return aiRankedIds;
        }

        // Identify interest types from user input
        var interestLower = interests.Select(i => i.ToLowerInvariant()).ToList();
        var hasFood = interestLower.Any(i => i.Contains("food") || i.Contains("restaurant") || i.Contains("dining"));
        var hasCultural = interestLower.Any(i => i.Contains("museum") || i.Contains("historic") || i.Contains("cultural") || i.Contains("monument"));

        _logger.LogDebug("Balance enforcement - User requested Food: {HasFood}, Cultural: {HasCultural}", hasFood, hasCultural);

        // Get POIs from AI ranking
        var rankedPois = aiRankedIds
            .Select(id => candidatePois.FirstOrDefault(p => p.Id == id))
            .Where(p => p != null)
            .Cast<PointOfInterest>()
            .ToList();

        // Categorize AI-selected POIs
        var foodCategories = new[] { "restaurant", "cafe", "food", "japanese", "chinese", "italian", "bar", "pub" };
        var culturalCategories = new[] { "museum", "gallery", "historic", "monument", "landmark", "church", "cathedral", "temple", "building" };

        var foodPois = rankedPois.Where(p => 
            !string.IsNullOrEmpty(p.Category) && foodCategories.Any(f => p.Category!.ToLowerInvariant().Contains(f))).ToList();
        var culturalPois = rankedPois.Where(p => 
            !string.IsNullOrEmpty(p.Category) && culturalCategories.Any(c => p.Category!.ToLowerInvariant().Contains(c))).ToList();

        _logger.LogDebug("AI selection contains - Food POIs: {FoodCount}, Cultural POIs: {CulturalCount}", 
            foodPois.Count, culturalPois.Count);

        // Check if balance enforcement is needed
        var needsFoodFix = hasFood && foodPois.Count == 0;
        var needsCulturalFix = hasCultural && culturalPois.Count == 0;
        var needsFoodLimit = foodPois.Count > 2;

        if (!needsFoodFix && !needsCulturalFix && !needsFoodLimit)
        {
            _logger.LogInformation("AI ranking has good balance - no enforcement needed");
            return aiRankedIds;
        }

        _logger.LogWarning("AI ranking needs balance correction - Food fix: {FoodFix}, Cultural fix: {CulturalFix}, Food limit: {FoodLimit}", 
            needsFoodFix, needsCulturalFix, needsFoodLimit);

        // Start with non-food, non-cultural POIs as base
        var balancedPois = rankedPois.Where(p => 
            string.IsNullOrEmpty(p.Category) || 
            (!foodCategories.Any(f => p.Category.ToLowerInvariant().Contains(f)) &&
             !culturalCategories.Any(c => p.Category.ToLowerInvariant().Contains(c)))).ToList();

        // Add cultural POIs (all if user wants cultural, or keep AI selection if not)
        if (hasCultural)
        {
            if (culturalPois.Any())
            {
                balancedPois.AddRange(culturalPois.Take(3)); // Limit cultural to 3
            }
            else
            {
                // Find cultural POIs from candidates if AI missed them
                var candidateCultural = candidatePois.Where(p => 
                    !string.IsNullOrEmpty(p.Category) && culturalCategories.Any(c => p.Category!.ToLowerInvariant().Contains(c)))
                    .Take(2)
                    .ToList();
                balancedPois.AddRange(candidateCultural);
                _logger.LogInformation("Added {Count} cultural POIs from candidates to fix missing coverage", candidateCultural.Count);
            }
        }

        // Add food POIs (1-2 if user wants food, limit if too many)
        if (hasFood)
        {
            if (foodPois.Any())
            {
                balancedPois.AddRange(foodPois.Take(2)); // Limit to 2 food POIs
            }
            else
            {
                // Find food POIs from candidates if AI missed them
                var candidateFood = candidatePois.Where(p => 
                    !string.IsNullOrEmpty(p.Category) && foodCategories.Any(f => p.Category!.ToLowerInvariant().Contains(f)))
                    .Take(2)
                    .ToList();
                balancedPois.AddRange(candidateFood);
                _logger.LogInformation("Added {Count} food POIs from candidates to fix missing coverage", candidateFood.Count);
            }
        }

        // Return the balanced POI IDs
        var result = balancedPois.Select(p => p.Id).ToList();
        _logger.LogInformation("Balance enforcement complete - returning {Count} POIs with proper interest coverage", result.Count);
        
        return result;
    }
}