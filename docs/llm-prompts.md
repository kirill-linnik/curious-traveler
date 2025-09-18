# LLM Prompt Templates for Itinerary Creation

This document contains the exact prompt templates used by the Azure OpenAI service for itinerary creation. These templates are referenced in the `OpenAIService` implementation.

## General Calling Settings

### gpt-5-mini
- **Temperature**: 0.2
- **Top P**: 0.9  
- **Response Format**: json_object
- **Max Tokens**: 512-800
- **Seed**: Set for determinism

### gpt-5-chat
- **Temperature**: 0.4 (rerank), 0.6 (descriptions)
- **Top P**: 0.9
- **Response Format**: json_object
- **Max Tokens**: 1200-1800
- **Seed**: Set for determinism

## MINI#1 — Interests → Azure Maps Category IDs (gpt-5-mini)

### System Prompt
```text
You map free-text traveler interests to a vetted allowlist of Azure Maps POI category IDs.
Return ONLY JSON that conforms to the provided JSON Schema. 
Do not invent categories or IDs not in the allowlist. 
If nothing matches, return an empty array.
```

### User Prompt Template
```json
{
  "language": "{{language}}",
  "city": "{{cityName}}",
  "interestsInput": "{{interestsFreeText}}",
  "allowlist": [
    { "id": "category:museum", "labels": ["museum","art museum","gallery"] },
    { "id": "category:landmark", "labels": ["landmark","monument","historic"] },
    { "id": "category:park", "labels": ["park","garden","green space"] },
    { "id": "category:food", "labels": ["food","restaurant","street food","eat"] },
    { "id": "category:cafe", "labels": ["cafe","coffee","coffee shop"] },
    { "id": "category:market", "labels": ["market","bazaar","farmers market"] },
    { "id": "category:church", "labels": ["church","cathedral","temple"] }
  ],
  "maxCategories": 6
}
```

### JSON Schema
```json
{
  "type": "object",
  "properties": {
    "categoryIds": {
      "type": "array",
      "items": { "type": "string" },
      "description": "IDs from allowlist"
    }
  },
  "required": ["categoryIds"],
  "additionalProperties": false
}
```

### Example Output
```json
{ "categoryIds": ["category:food","category:museum","category:cafe"] }
```

## MINI#2 — Minimum Dwell Estimation per POI (gpt-5-mini)

### System Prompt
```text
Estimate a minimum recommended visit duration (minutes) for a POI given its category, popularity and attributes.
Use conservative but realistic values. Return only JSON; no prose.
If confidence is low, set lowConfidence: true and use a fallback-min threshold.
```

### User Prompt Template
```json
{
  "language": "{{language}}",
  "poi": {
    "name": "{{name}}",
    "category": "{{categoryStableId}}",
    "rating": {{ratingOrNull}},
    "reviewCount": {{reviewCountOrNull}},
    "tags": ["{{tag1}}","{{tag2}}"],
    "brief": "{{shortProviderDescription}}"
  },
  "defaults": {
    "museum": 90,
    "landmark": 30,
    "park": 45,
    "gallery": 60,
    "food": 30,
    "cafe": 30,
    "church": 30
  },
  "minFloorMinutes": 20,
  "maxCeilingMinutes": 180
}
```

### JSON Schema
```json
{
  "type": "object",
  "properties": {
    "minVisitMinutes": { "type": "integer", "minimum": 10, "maximum": 240 },
    "lowConfidence": { "type": "boolean" }
  },
  "required": ["minVisitMinutes","lowConfidence"],
  "additionalProperties": false
}
```

### Example Output
```json
{ "minVisitMinutes": 120, "lowConfidence": false }
```

## CHAT#1 — Rerank Candidate POIs (gpt-5-chat)

### System Prompt
```text
You rerank candidate POIs for a city itinerary. Optimize for:
1) Relevance to user interests, 2) Popularity/ratings, 3) Diversity of types, 4) Spatial reasonableness.
Do not hallucinate distances; use provided distances. 
Return strictly JSON conforming to the schema. No prose.
```

### User Prompt Template
```json
{
  "language": "{{language}}",
  "mode": "{{mode}}",
  "maxPois": {{maxPois}},
  "timeBudgetMinutes": {{maxDurationMinutes}},
  "interests": ["{{interest1}}","{{interest2}}"],
  "candidates": [
    {
      "id": "poi_1",
      "name": "Kumu Art Museum",
      "category": "category:museum",
      "location": {"latitude": 24.03123, "longitude": 49.0313 },
      "rating": 4.7,
      "reviewCount": 12000,
      "distanceFromStartMeters": 3200,
      "approxBetweenMeters": 1500,
      "isOpenNow": true,
      "minVisitMinutes": 90
    }
  ]
}
```

### JSON Schema
```json
{
  "type": "object",
  "properties": {
    "orderedPoiIds": { "type": "array", "items": { "type": "string" } },
    "rationale": { "type": "string" }
  },
  "required": ["orderedPoiIds","rationale"],
  "additionalProperties": false
}
```

### Example Output
```json
{
  "orderedPoiIds": ["poi_1","poi_7","poi_3","poi_2","poi_6"],
  "rationale": "Museums and food preferences prioritized; high ratings; mixed types; reasonable spacing."
}
```

## CHAT#2 — Localized POI Descriptions (gpt-5-chat)

### System Prompt
```text
You produce concise, accurate, city-guide style descriptions in the requested language.
2–4 sentences, no marketing fluff, no hallucinations. If data is insufficient, be generic but truthful.
Return JSON only.
```

### User Prompt Template
```json
{
  "language": "{{language}}",
  "city": "{{cityName}}",
  "stops": [
    {
      "name": "Kumu Art Museum",
      "address": "Weizenbergi 34, Tallinn",
      "location": {"latitude": 24.03123, "longitude": 49.0313 },
      "category": "category:museum",
      "facts": ["modern art", "Estonian art collection"],
      "minVisitMinutes": 90
    }
  ]
}
```

### JSON Schema
```json
{
  "type": "object",
  "properties": {
    "descriptions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "text": { "type": "string" }
        },
        "required": ["name","text"],
        "additionalProperties": false
      }
    }
  },
  "required": ["descriptions"],
  "additionalProperties": false
}
```

### Example Output
```json
{
  "descriptions": [
    {
      "name": "Kumu Art Museum",
      "text": "Kumu is Estonia's leading museum of modern and contemporary art, tracing the country's visual culture from the 18th century to today. The striking building overlooks Kadriorg park and often hosts thoughtful temporary exhibitions."
    }
  ]
}
```

## Implementation Notes

### Determinism and Safety
- Set `response_format: json_object` and validate JSON against schemas
- Use low temperature and seed for stability
- On parse failure, retry once with stricter system reminder
- Truncate inputs to safe token budgets
- Never pass secrets to models

### Timeouts and Retries
- **gpt-5-mini**: 5-8s timeout, single retry with jittered backoff
- **gpt-5-chat**: 12-20s timeout, single retry with jittered backoff

### Error Handling
- Reject overly long `interests` with 400 status
- Include only public metadata in prompts
- Log warnings for low confidence results
- Provide fallback values for all operations

### Usage in Code
These templates are implemented in `Services/AI/OpenAIService.cs` with the following methods:
- `MapInterestsToCategoriesAsync()` - Uses MINI#1
- `EstimateMinVisitMinutesAsync()` - Uses MINI#2  
- `RerankPoisAsync()` - Uses CHAT#1
- `GenerateLocalizedDescriptionsAsync()` - Uses CHAT#2