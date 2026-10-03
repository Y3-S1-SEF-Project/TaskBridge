using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace backend.Api.AI;

public sealed class JobCompletionEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string BookingReference { get; set; } = string.Empty;
    public Guid? BookingId { get; set; }
    public Guid? ProviderId { get; set; }
    public string ProviderName { get; set; } = string.Empty;
    public Guid? CustomerId { get; set; }
    public string CustomerName { get; set; } = "Customer";
    public string ServiceTitle { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string ProviderNotes { get; set; } = string.Empty;
    public string? BeforePhotoUrl { get; set; }

    [NotMapped]
    public List<string> BeforePhotoUrls
    {
        get
        {
            if (string.IsNullOrWhiteSpace(BeforePhotoUrl)) return new();
            if (BeforePhotoUrl.TrimStart().StartsWith("["))
            {
                try { return JsonSerializer.Deserialize<List<string>>(BeforePhotoUrl) ?? new(); }
                catch { }
            }
            return new List<string> { BeforePhotoUrl };
        }
    }

    public string AfterPhotoUrls { get; set; } = "[]"; // JSON array of string URLs
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset EndedAt { get; set; }
    public int DurationMinutes { get; set; }
    public decimal HourlyRate { get; set; }
    public decimal CalculatedPrice { get; set; }
    public bool AiVerificationPassed { get; set; }
    public int AiConfidenceScore { get; set; }
    public string AiComparisonAnalysis { get; set; } = string.Empty;
    public string AiVerifiedTasks { get; set; } = "[]"; // JSON array of verified tasks
    public string AiMissingDetails { get; set; } = "[]"; // JSON array of missing items
    public string Status { get; set; } = "PendingAiReview"; // PendingAiReview, AiApproved, RevisionRequested, CustomerApproved, Disputed
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed class FeedbackEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string BookingReference { get; set; } = string.Empty;
    public Guid? CustomerId { get; set; }
    public string CustomerName { get; set; } = "Customer";
    public Guid? ProviderId { get; set; }
    public string ProviderName { get; set; } = string.Empty;
    public int Rating { get; set; } = 5; // 1 to 5
    public string Comment { get; set; } = string.Empty;
    public string Status { get; set; } = "Approved"; // Approved, Flagged, Pending Review
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public class StartJobRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("beforePhotoUrl")]
    public string? BeforePhotoUrl { get; set; }
}

public class SubmitCompletionRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("providerNotes")]
    public string ProviderNotes { get; set; } = string.Empty;

    [JsonPropertyName("beforePhotoUrl")]
    public string? BeforePhotoUrl { get; set; }

    [JsonPropertyName("beforePhotoUrls")]
    public List<string> BeforePhotoUrls { get; set; } = new();

    [JsonPropertyName("afterPhotoUrls")]
    public List<string> AfterPhotoUrls { get; set; } = new();

    [JsonPropertyName("startedAt")]
    public DateTimeOffset? StartedAt { get; set; }

    [JsonPropertyName("endedAt")]
    public DateTimeOffset? EndedAt { get; set; }

    [JsonPropertyName("hourlyRate")]
    public decimal? HourlyRate { get; set; }
}

public class SubmitToCustomerRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;
}

public class CustomerApprovalRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("customerNotes")]
    public string? CustomerNotes { get; set; }
}

public class RequestRevisionRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("reason")]
    public string Reason { get; set; } = string.Empty;
}

public class SubmitFeedbackRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }

    [JsonPropertyName("providerId")]
    public string? ProviderId { get; set; }

    [JsonPropertyName("providerName")]
    public string? ProviderName { get; set; }

    [JsonPropertyName("rating")]
    public int Rating { get; set; } = 5;

    [JsonPropertyName("comment")]
    public string Comment { get; set; } = string.Empty;
}

public class ReviewAnalyzeResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("verificationPassed")]
    public bool VerificationPassed { get; set; }

    [JsonPropertyName("confidenceScore")]
    public int ConfidenceScore { get; set; }

    [JsonPropertyName("comparisonAnalysis")]
    public string ComparisonAnalysis { get; set; } = string.Empty;

    [JsonPropertyName("verifiedTasks")]
    public List<string> VerifiedTasks { get; set; } = new();

    [JsonPropertyName("missingDetails")]
    public List<string> MissingDetails { get; set; } = new();

    [JsonPropertyName("durationMinutes")]
    public int DurationMinutes { get; set; }

    [JsonPropertyName("durationFormatted")]
    public string DurationFormatted { get; set; } = string.Empty;

    [JsonPropertyName("hourlyRate")]
    public decimal HourlyRate { get; set; }

    [JsonPropertyName("calculatedPrice")]
    public decimal CalculatedPrice { get; set; }

    [JsonPropertyName("priceFormatted")]
    public string PriceFormatted { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("model")]
    public string Model { get; set; } = "gpt-4o-mini";

    [JsonPropertyName("latencyMs")]
    public long LatencyMs { get; set; }
}
