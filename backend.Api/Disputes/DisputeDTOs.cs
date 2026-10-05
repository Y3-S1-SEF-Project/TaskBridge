using System.Text.Json.Serialization;

namespace TaskBridge.Api.Disputes;

public sealed class CreateDisputeRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("reasonCategory")]
    public string ReasonCategory { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("desiredResolution")]
    public string DesiredResolution { get; set; } = string.Empty;

    [JsonPropertyName("evidencePhotoUrls")]
    public List<string>? EvidencePhotoUrls { get; set; }

    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }
}

public sealed class ResolveDisputeRequest
{
    [JsonPropertyName("resolutionAction")]
    public string ResolutionAction { get; set; } = "Completed"; // "Completed" (releases to completed) or "Cancelled" (marks cancelled)

    [JsonPropertyName("resolutionSummary")]
    public string ResolutionSummary { get; set; } = string.Empty;

    [JsonPropertyName("adminName")]
    public string? AdminName { get; set; }
}

public sealed class DisputeResponseDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("disputeReference")]
    public string DisputeReference { get; set; } = string.Empty;

    [JsonPropertyName("bookingId")]
    public Guid? BookingId { get; set; }

    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("customerId")]
    public Guid? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string CustomerName { get; set; } = string.Empty;

    [JsonPropertyName("customerPhone")]
    public string? CustomerPhone { get; set; }

    [JsonPropertyName("customerEmail")]
    public string? CustomerEmail { get; set; }

    [JsonPropertyName("providerId")]
    public Guid? ProviderId { get; set; }

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = string.Empty;

    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("feeAmount")]
    public decimal FeeAmount { get; set; }

    [JsonPropertyName("reasonCategory")]
    public string ReasonCategory { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("desiredResolution")]
    public string DesiredResolution { get; set; } = string.Empty;

    [JsonPropertyName("beforePhotoUrls")]
    public List<string> BeforePhotoUrls { get; set; } = new();

    [JsonPropertyName("afterPhotoUrls")]
    public List<string> AfterPhotoUrls { get; set; } = new();

    [JsonPropertyName("customerEvidencePhotoUrls")]
    public List<string> CustomerEvidencePhotoUrls { get; set; } = new();

    [JsonPropertyName("status")]
    public string Status { get; set; } = "PendingAdminReview";

    [JsonPropertyName("resolutionSummary")]
    public string? ResolutionSummary { get; set; }

    [JsonPropertyName("resolutionAction")]
    public string? ResolutionAction { get; set; }

    [JsonPropertyName("resolvedByAdminName")]
    public string? ResolvedByAdminName { get; set; }

    [JsonPropertyName("resolvedAt")]
    public DateTimeOffset? ResolvedAt { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class DisputesSummaryResponseDto
{
    [JsonPropertyName("totalDisputes")]
    public int TotalDisputes { get; set; }

    [JsonPropertyName("pendingCount")]
    public int PendingCount { get; set; }

    [JsonPropertyName("resolvedCount")]
    public int ResolvedCount { get; set; }

    [JsonPropertyName("disputes")]
    public List<DisputeResponseDto> Disputes { get; set; } = new();
}
