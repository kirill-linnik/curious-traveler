using System.Text.Json.Serialization;

namespace CuriousTraveler.Api.Models.AzureMaps;

public class PoiCategoryTreeResponse
{
    [JsonPropertyName("poiCategories")]
    public List<PoiCategory> PoiCategories { get; set; } = new();
}

public class PoiCategory
{
    [JsonPropertyName("id")]
    public int Id { get; set; }
    
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    
    [JsonPropertyName("childCategoryIds")]
    public List<int> ChildCategoryIds { get; set; } = new();
    
    [JsonPropertyName("synonyms")]
    public List<string> Synonyms { get; set; } = new();
    
    // Helper properties
    public List<string> AllLabels => new List<string> { Name }.Concat(Synonyms).ToList();
    public string IdString => Id.ToString();
}