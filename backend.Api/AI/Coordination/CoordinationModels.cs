using System.Text.Json.Serialization;

namespace backend.Api.AI;

public class ProviderQuotationDto
{
    [JsonPropertyName("providerId")]
    public string ProviderId { get; set; } = string.Empty;

    [JsonPropertyName("fullName")]
    public string FullName { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("profilePhotoUrl")]
    public string? ProfilePhotoUrl { get; set; }

    [JsonPropertyName("phone")]
    public string Phone { get; set; } = string.Empty;

    [JsonPropertyName("quotedPrice")]
    public decimal QuotedPrice { get; set; }

    [JsonPropertyName("availableTime")]
    public string AvailableTime { get; set; } = string.Empty;

    [JsonPropertyName("distanceKm")]
    public double DistanceKm { get; set; }

    [JsonPropertyName("rating")]
    public double Rating { get; set; }

    [JsonPropertyName("reviewCount")]
    public int ReviewCount { get; set; }

    [JsonPropertyName("notes")]
    public string Notes { get; set; } = string.Empty;

    [JsonPropertyName("matchScore")]
    public int MatchScore { get; set; } = 90;

    [JsonPropertyName("isRecommended")]
    public bool IsRecommended { get; set; }
}

public class CoordinationEvaluateRequest
{
    [JsonPropertyName("jobPlan")]
    public JobPlanDetails JobPlan { get; set; } = new();

    [JsonPropertyName("candidateProviders")]
    public List<ProviderQuotationDto> CandidateProviders { get; set; } = new();

    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }
}


