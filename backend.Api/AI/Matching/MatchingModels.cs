using System.Text.Json.Serialization;

namespace backend.Api.AI;

public class MatchingRequest
{
    [JsonPropertyName("serviceRequestId")]
    public string? ServiceRequestId { get; set; }

    [JsonPropertyName("jobPlan")]
    public JobPlanDetails JobPlan { get; set; } = new();

    [JsonPropertyName("customerUserId")]
    public string? CustomerUserId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }

    [JsonPropertyName("maxResults")]
    public int MaxResults { get; set; } = 3;
}

public class ScoreBreakdown
{
    [JsonPropertyName("skillScore")]
    public double SkillScore { get; set; } // max 35

    [JsonPropertyName("locationScore")]
    public double LocationScore { get; set; } // max 25

    [JsonPropertyName("budgetScore")]
    public double BudgetScore { get; set; } // max 20

    [JsonPropertyName("ratingScore")]
    public double RatingScore { get; set; } // max 20
}

public class MatchedProviderDto
{
    [JsonPropertyName("providerId")]
    public Guid ProviderId { get; set; }

    [JsonPropertyName("userId")]
    public Guid UserId { get; set; }

    [JsonPropertyName("fullName")]
    public string FullName { get; set; } = string.Empty;

    [JsonPropertyName("profilePhotoUrl")]
    public string? ProfilePhotoUrl { get; set; }

    [JsonPropertyName("phone")]
    public string Phone { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("skills")]
    public string? Skills { get; set; }

    [JsonPropertyName("serviceAreas")]
    public string? ServiceAreas { get; set; }

    [JsonPropertyName("distanceKm")]
    public double DistanceKm { get; set; }

    [JsonPropertyName("hourlyRate")]
    public decimal HourlyRate { get; set; }

    [JsonPropertyName("rating")]
    public double Rating { get; set; }

    [JsonPropertyName("reviewCount")]
    public int ReviewCount { get; set; }

    [JsonPropertyName("matchScore")]
    public int MatchScore { get; set; } // e.g. 98

    [JsonPropertyName("aiMatchReason")]
    public string AiMatchReason { get; set; } = string.Empty;

    [JsonPropertyName("scoreBreakdown")]
    public ScoreBreakdown ScoreBreakdown { get; set; } = new();

    [JsonPropertyName("isVerified")]
    public bool IsVerified { get; set; } = false;

    [JsonPropertyName("verificationStatus")]
    public string VerificationStatus { get; set; } = "Unverified";

    [JsonPropertyName("verificationDocumentUrl")]
    public string? VerificationDocumentUrl { get; set; }

    [JsonPropertyName("verificationDocumentType")]
    public string? VerificationDocumentType { get; set; }
}

public class MatchingResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; } = true;

    [JsonPropertyName("jobPlan")]
    public JobPlanDetails JobPlan { get; set; } = new();

    [JsonPropertyName("matchedProviders")]
    public List<MatchedProviderDto> MatchedProviders { get; set; } = new();

    [JsonPropertyName("candidatePoolCount")]
    public int CandidatePoolCount { get; set; }

    [JsonPropertyName("matchAuditId")]
    public Guid? MatchAuditId { get; set; }

    [JsonPropertyName("latencyMs")]
    public long LatencyMs { get; set; }

    [JsonPropertyName("tokensUsed")]
    public int TokensUsed { get; set; }

    [JsonPropertyName("model")]
    public string Model { get; set; } = "gpt-4o-mini";
}
