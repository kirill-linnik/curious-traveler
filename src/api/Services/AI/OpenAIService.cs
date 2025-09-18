using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Identity;
using OpenAI.Chat;
using System.ClientModel;
using CuriousTraveler.Api.Models.AzureMaps;
using CuriousTraveler.Api.Models.Configuration;
using CuriousTraveler.Api.Models.Itinerary;
using Microsoft.Extensions.Options;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CuriousTraveler.Api.Services.AI;

public interface IOpenAIService
{
    Task<List<string>> MapInterestsToCategoriesAsync(
        string interests, 
        string language, 
        string cityName, 
        List<CategoryMapping> allowlist, 
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Maps user interests to Azure Maps POI categories using the dynamic category tree
    /// </summary>
    Task<List<string>> MapInterestsToAzureMapsCategoriesAsync(
        string interests,
        string language,
        string cityName,
        List<PoiCategory> availableCategories,
        CancellationToken cancellationToken = default);

    Task<int> EstimateMinVisitMinutesAsync(
        PointOfInterest poi, 
        string language, 
        Dictionary<string, int> defaults, 
        int minFloorMinutes, 
        int maxCeilingMinutes, 
        CancellationToken cancellationToken = default);

    Task<List<string>> RerankPoisAsync(
        List<PointOfInterest> candidates, 
        List<string> interests, 
        string language, 
        TravelMode mode, 
        int maxPois, 
        int timeBudgetMinutes, 
        CancellationToken cancellationToken = default);

    Task<Dictionary<string, string>> GenerateLocalizedDescriptionsAsync(
        List<PointOfInterest> stops, 
        string language, 
        string cityName, 
        CancellationToken cancellationToken = default);
}

public class OpenAIService : IOpenAIService
{
    private readonly AzureOpenAIClient _openAIClient;
    private readonly AzureOpenAIOptions _options;
    private readonly ILogger<OpenAIService> _logger;

    public OpenAIService(
        IOptions<AzureOpenAIOptions> options,
        ILogger<OpenAIService> logger)
    {
        _options = options.Value;
        _logger = logger;

        _openAIClient = new AzureOpenAIClient(
            new Uri(_options.Endpoint),
            new ApiKeyCredential(_options.ApiKey));
    }

    public async Task<List<string>> MapInterestsToCategoriesAsync(
        string interests, 
        string language, 
        string cityName, 
        List<CategoryMapping> allowlist,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var allowedCategories = string.Join(", ", allowlist.Select(c => $"{c.Id} ({c.AzureMapsCategory})"));
            
            var systemPrompt = GetInterestMappingPrompt();
            var userPrompt = $@"User interests: {interests}
City: {cityName}
Language preference: {language}
Allowed categories (id (azure_maps_category)): {allowedCategories}";

            var chatClient = _openAIClient.GetChatClient(_options.Gpt5MiniDeployment);
            
            var messages = new List<ChatMessage>
            {
                ChatMessage.CreateSystemMessage(systemPrompt),
                ChatMessage.CreateUserMessage(userPrompt)
            };

            var options = new ChatCompletionOptions
            {
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat()
            };

            var response = await chatClient.CompleteChatAsync(messages, options, cancellationToken);
            
            var jsonContent = response.Value.Content[0].Text;
            var result = JsonSerializer.Deserialize<InterestMappingResult>(jsonContent);
            
            return result?.MappedCategories ?? new List<string>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to map interests to categories for input: {Interests}", interests);
            
            // Fallback: return first 3 allowed categories
            return allowlist.Take(3).Select(c => c.Id).ToList();
        }
    }

    public async Task<List<string>> MapInterestsToAzureMapsCategoriesAsync(
        string interests,
        string language,
        string cityName,
        List<PoiCategory> availableCategories,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Select most relevant categories for the prompt (to avoid token limits)
            var relevantCategories = availableCategories
                .Where(c => IsRelevantCategory(c))
                .Take(50) // Limit to top 50 most relevant categories
                .ToList();

            var categoryList = string.Join("\n", relevantCategories.Select(c => 
                $"ID: {c.Id}, Name: {c.Name}, Synonyms: [{string.Join(", ", c.Synonyms)}]"));
            
            var systemPrompt = GetAzureMapsInterestMappingPrompt();
            var userPrompt = $@"User interests: {interests}
City: {cityName}
Language preference: {language}

Available Azure Maps POI Categories:
{categoryList}";

            var chatClient = _openAIClient.GetChatClient(_options.Gpt5MiniDeployment);
            
            var messages = new List<ChatMessage>
            {
                ChatMessage.CreateSystemMessage(systemPrompt),
                ChatMessage.CreateUserMessage(userPrompt)
            };

            var options = new ChatCompletionOptions
            {
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat()
            };

            var response = await chatClient.CompleteChatAsync(messages, options, cancellationToken);
            
            var jsonContent = response.Value.Content[0].Text;
            var result = JsonSerializer.Deserialize<AzureMapsInterestMappingResult>(jsonContent);
            
            var categoryIds = result?.CategoryIds ?? new List<string>();
            
            // Validate that returned IDs exist in available categories
            var validCategoryIds = categoryIds
                .Where(id => availableCategories.Any(c => c.IdString == id))
                .ToList();
            
            return validCategoryIds;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to map interests to Azure Maps categories for input: {Interests}", interests);
            
            // Fallback: return some general categories
            var fallbackCategories = availableCategories
                .Where(c => IsGeneralCategory(c))
                .Take(3)
                .Select(c => c.IdString)
                .ToList();
                
            return fallbackCategories;
        }
    }

    public async Task<int> EstimateMinVisitMinutesAsync(
        PointOfInterest poi, 
        string language, 
        Dictionary<string, int> defaults, 
        int minFloorMinutes, 
        int maxCeilingMinutes,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var systemPrompt = GetDwellEstimationPrompt();
            var userPrompt = $@"POI category: {poi.Category}
POI name: {poi.Name}
City location context: {poi.Address}
Default estimates by category: {JsonSerializer.Serialize(defaults)}
Minimum floor: {minFloorMinutes} minutes
Maximum ceiling: {maxCeilingMinutes} minutes";

            var chatClient = _openAIClient.GetChatClient(_options.Gpt5MiniDeployment);
            
            var messages = new List<ChatMessage>
            {
                ChatMessage.CreateSystemMessage(systemPrompt),
                ChatMessage.CreateUserMessage(userPrompt)
            };

            var options = new ChatCompletionOptions
            {
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat()
            };

            var response = await chatClient.CompleteChatAsync(messages, options, cancellationToken);
            
            var jsonContent = response.Value.Content[0].Text;
            var result = JsonSerializer.Deserialize<DwellEstimationResult>(jsonContent);
            
            var estimate = result?.EstimatedMinutes ?? 60;
            return Math.Max(minFloorMinutes, Math.Min(maxCeilingMinutes, estimate));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to estimate dwell time for POI: {PoiName}", poi.Name);
            
            // Fallback based on category
            var fallback = poi.Category?.ToLowerInvariant() switch
            {
                "museum" => 120,
                "restaurant" => 90,
                "attraction" => 60,
                "shop" => 30,
                _ => 60
            };
            
            return Math.Max(minFloorMinutes, Math.Min(maxCeilingMinutes, fallback));
        }
    }

    public async Task<List<string>> RerankPoisAsync(
        List<PointOfInterest> candidates, 
        List<string> interests, 
        string language, 
        TravelMode mode, 
        int maxPois, 
        int timeBudgetMinutes,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var candidatesJson = JsonSerializer.Serialize(candidates.Select(p => new
            {
                Id = p.Id,
                Name = p.Name,
                Category = p.Category,
                Rating = p.Rating,
                EstimatedVisitMinutes = p.EstimatedMinVisitMinutes
            }));

            var systemPrompt = GetPoiRerankingPrompt();
            var userPrompt = $@"POI candidates: {candidatesJson}
User interests: {string.Join(", ", interests)}
Travel mode: {mode}
Maximum POIs to select: {maxPois}
Total time budget: {timeBudgetMinutes} minutes
Language preference: {language}";

            var chatClient = _openAIClient.GetChatClient(_options.Gpt5ChatDeployment);
            
            var messages = new List<ChatMessage>
            {
                ChatMessage.CreateSystemMessage(systemPrompt),
                ChatMessage.CreateUserMessage(userPrompt)
            };

            var options = new ChatCompletionOptions
            {
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat()
            };

            var response = await chatClient.CompleteChatAsync(messages, options, cancellationToken);
            
            var jsonContent = response.Value.Content[0].Text;
            var result = JsonSerializer.Deserialize<PoiRerankingResult>(jsonContent);
            
            return result?.RankedIds ?? candidates.Take(maxPois).Select(p => p.Id).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to rerank POIs for interests: {Interests}", string.Join(", ", interests));
            return candidates.Take(maxPois).Select(p => p.Id).ToList();
        }
    }

    public async Task<Dictionary<string, string>> GenerateLocalizedDescriptionsAsync(
        List<PointOfInterest> stops, 
        string language, 
        string cityName,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var stopsJson = JsonSerializer.Serialize(stops.Select(p => new
            {
                Id = p.Id,
                Name = p.Name,
                Address = p.Address,
                Category = p.Category,
                Description = p.Description,
                Rating = p.Rating,
                ReviewCount = p.ReviewCount,
                Tags = p.Tags,
                EstimatedVisitMinutes = p.EstimatedMinVisitMinutes
            }));

            var systemPrompt = GetDescriptionGenerationPrompt();
            var userPrompt = $@"POIs for description: {stopsJson}
Target language: {language}
City: {cityName}";

            var chatClient = _openAIClient.GetChatClient(_options.Gpt5ChatDeployment);
            
            var messages = new List<ChatMessage>
            {
                ChatMessage.CreateSystemMessage(systemPrompt),
                ChatMessage.CreateUserMessage(userPrompt)
            };

            var options = new ChatCompletionOptions
            {
                ResponseFormat = ChatResponseFormat.CreateJsonObjectFormat()
            };

            var response = await chatClient.CompleteChatAsync(messages, options, cancellationToken);
            
            var jsonContent = response.Value.Content[0].Text;
            var result = JsonSerializer.Deserialize<DescriptionGenerationResult>(jsonContent);
            
            return result?.Descriptions ?? stops.ToDictionary(p => p.Id, p => p.Description ?? p.Name);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate localized descriptions for {Count} POIs", stops.Count);
            return stops.ToDictionary(p => p.Id, p => p.Description ?? p.Name);
        }
    }

    // LLM Prompt Templates
    private static string GetInterestMappingPrompt() => @"
You are an expert travel advisor. Map user interests to Azure Maps POI categories.

TASK: Given user interests, map them to the most relevant POI categories from the allowlist.

RULES:
1. Return only categories from the provided allowlist
2. Maximum 5 categories
3. Prioritize categories that best match user interests
4. Consider cultural and activity-based preferences

OUTPUT FORMAT (JSON):
{
  ""mappedCategories"": [""category1"", ""category2"", ""category3""]
}

Be concise and accurate in your mapping.";

    private static string GetDwellEstimationPrompt() => @"
You are an expert travel planner. Estimate realistic visit duration for POIs.

TASK: Estimate minimum visit time in minutes for the given POI.

FACTORS TO CONSIDER:
1. POI type (museum, restaurant, attraction, etc.)
2. Typical visitor behavior
3. POI size and complexity
4. Location context
5. Provided default estimates and constraints

GUIDELINES:
- Use provided defaults as baseline
- Respect minimum and maximum constraints
- Consider POI-specific factors

OUTPUT FORMAT (JSON):
{
  ""estimatedMinutes"": 90,
  ""reasoning"": ""Brief explanation""
}

Provide realistic, practical estimates within the given constraints.";

    private static string GetPoiRerankingPrompt() => @"
You are an expert travel curator. Select and rank POIs ensuring MANDATORY COVERAGE of all user interests within constraints.

TASK: Select POIs that provide COMPLETE representation of all mentioned user interests while respecting limits.

MANDATORY COVERAGE RULES:
1. EVERY mentioned interest type MUST have at least 1 POI in final selection
2. FOOD LIMITS: Maximum 2 food-related POIs (but minimum 1 if food is mentioned)
3. CULTURAL SITES: Must include if museums/historic sites/culture mentioned
4. BALANCED DISTRIBUTION: Don't over-represent one interest at expense of others

SELECTION PRIORITY (in order):
1. COVERAGE COMPLETENESS: Does selection include ALL user interest types?
2. MANDATORY MINIMUMS: At least 1 POI per mentioned interest type
3. FOOD STRATEGY: If food mentioned, include 1-2 food POIs with good timing
4. QUALITY within constraints: Best POIs that meet coverage requirements
5. Practical logistics: Travel time and visit duration optimization

FOOD INCLUSION LOGIC:
- Food mentioned + other interests: MUST include 1-2 food POIs
- Choose strategic meal timing: lunch venue + coffee/dessert if 2 food POIs
- If only 1 food POI: Choose venue suitable for main meal

VALIDATION CHECKLIST:
- User said ""museums"" → Is there a museum/gallery POI?
- User said ""food"" → Is there a restaurant/cafe POI?  
- User said ""historic sites"" → Is there a historic/landmark POI?

OUTPUT FORMAT (JSON):
{
  ""rankedIds"": [""id1"", ""id2"", ""id3""],
  ""reasoning"": ""Explanation showing complete interest coverage and how each mentioned interest is represented""
}

CRITICAL: If user mentions an interest type, it MUST be represented in final POI selection. Incomplete coverage is unacceptable.";

    private static string GetDescriptionGenerationPrompt() => @"
You are a charismatic local guide who has lived in this city for decades. Write descriptions as if you're personally telling a traveler standing right there why this place is special, sharing insider knowledge and candid stories that only locals know.

VOICE & TONE:
- Write like a knowledgeable friend sharing a secret
- Use ""you'll"" and ""you'll find"" to make it personal and immediate
- Include specific sensory details (what you'll see, hear, smell, feel)
- Share honest local insights, not just promotional language
- Reveal what makes locals choose this place over alternatives

CONTENT TO INCLUDE:
- WHY locals love this place (the real reason, not just the obvious)
- WHEN to visit for the best experience (timing, atmosphere)  
- WHAT to notice that tourists miss (hidden details, local customs)
- HOW this place fits into local culture and daily life
- SENSORY details that paint a vivid picture of being there

INSIDER ELEMENTS TO WEAVE IN:
- Local tips: ""Ask for..."" ""Look for..."" ""The locals know to...""
- Atmospheric details: lighting, sounds, crowd dynamics, energy
- Cultural context: why this matters to the community
- Practical wisdom: best times, what to order, hidden features
- Authentic experiences: how to experience it like a local

STRUCTURE (2-3 sentences):
1. Hook with what makes it special/why locals love it
2. Vivid sensory description of the experience 
3. Insider tip or local secret that enhances the visit

AVOID:
- Generic promotional language (""popular destination"")
- Tourist guidebook tone 
- Basic factual descriptions without personality
- Clichés like ""hidden gem"" or ""must-visit""

OUTPUT FORMAT (JSON):
{
  ""descriptions"": {
    ""poi_id_1"": ""Local insider description with authentic voice and specific details"",
    ""poi_id_2"": ""Personal recommendation with sensory details and local tips""
  }
}

Write as if you're there with them, pointing out details and sharing stories that transform a simple visit into an authentic local experience.";

    private static string GetAzureMapsInterestMappingPrompt() => @"
You are an expert travel advisor with deep knowledge of Azure Maps POI categories.

TASK: Map user interests to Azure Maps POI category IDs ensuring MANDATORY REPRESENTATION of each interest type.

CRITICAL BALANCE RULES:
1. EVERY distinct interest type MUST be represented (e.g., if user wants ""museums, food, historic sites"" - you MUST include categories for ALL THREE)
2. For multiple interests: Allocate categories proportionally (3-4 interests = 1-2 categories each)
3. For FOOD interests: Include 1-2 food categories but DO NOT SKIP food if mentioned
4. For CULTURAL interests: Include relevant museum/historic/landmark categories
5. NEVER completely ignore any mentioned interest type

ALLOCATION STRATEGY:
- 1 interest mentioned: Use 3-5 categories for depth
- 2 interests mentioned: 2-3 categories each for balance  
- 3+ interests mentioned: 1-2 categories each for coverage

FOOD CATEGORY HANDLING:
- If food is mentioned: MUST include at least 1 food-related category
- Choose diverse food types if allocating 2 food categories
- Examples: restaurant + cafe, dining + coffee shop

OUTPUT FORMAT (JSON):
{
  ""categoryIds"": [""7317"", ""9361"", ""7315""],
  ""reasoning"": ""Explanation showing mandatory representation of each mentioned interest""
}

CRITICAL: If a user mentions an interest, it MUST appear in your category selection. NO EXCEPTIONS.";

    private static bool IsRelevantCategory(PoiCategory category)
    {
        // Filter to common travel/tourism categories
        var relevantNames = new[]
        {
            "restaurant", "museum", "landmark", "park", "church", "temple", "cathedral",
            "gallery", "monument", "historic", "market", "cafe", "shopping", "theater",
            "attraction", "entertainment", "cultural", "scenic", "viewpoint", "beach",
            "hotel", "accommodation", "transport", "station", "airport", "hospital",
            "pharmacy", "bank", "atm", "gas", "fuel", "parking"
        };
        
        var allLabels = category.AllLabels.Select(l => l.ToLowerInvariant());
        return relevantNames.Any(relevant => 
            allLabels.Any(label => label.Contains(relevant) || relevant.Contains(label)));
    }
    
    private static bool IsGeneralCategory(PoiCategory category)
    {
        // Common fallback categories that are generally useful
        var generalNames = new[] { "restaurant", "landmark", "park", "museum", "attraction" };
        var allLabels = category.AllLabels.Select(l => l.ToLowerInvariant());
        return generalNames.Any(general => 
            allLabels.Any(label => label.Contains(general)));
    }
}

// Response DTOs for JSON deserialization
public class InterestMappingResult
{
    [JsonPropertyName("mappedCategories")]
    public List<string> MappedCategories { get; set; } = new();
}

public class DwellEstimationResult
{
    [JsonPropertyName("estimatedMinutes")]
    public int EstimatedMinutes { get; set; }
    
    [JsonPropertyName("reasoning")]
    public string? Reasoning { get; set; }
}

public class PoiRerankingResult
{
    [JsonPropertyName("rankedIds")]
    public List<string> RankedIds { get; set; } = new();
    
    [JsonPropertyName("reasoning")]
    public string? Reasoning { get; set; }
}

public class DescriptionGenerationResult
{
    [JsonPropertyName("descriptions")]
    public Dictionary<string, string> Descriptions { get; set; } = new();
}

public class AzureMapsInterestMappingResult
{
    [JsonPropertyName("categoryIds")]
    public List<string> CategoryIds { get; set; } = new();
    
    [JsonPropertyName("reasoning")]
    public string? Reasoning { get; set; }
}