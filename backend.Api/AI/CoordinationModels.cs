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
}

public class BookingDetailsDto
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = string.Empty;

    [JsonPropertyName("customerName")]
    public string CustomerName { get; set; } = string.Empty;

    [JsonPropertyName("location")]
    public string Location { get; set; } = string.Empty;

    [JsonPropertyName("schedule")]
    public string Schedule { get; set; } = string.Empty;

    [JsonPropertyName("price")]
    public decimal Price { get; set; }

    [JsonPropertyName("priceFormatted")]
    public string PriceFormatted { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Upcoming"; // Upcoming, Active, Completed, Cancelled
}

public class BookingProposalResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; } = true;

    [JsonPropertyName("recommendedProviderId")]
    public string RecommendedProviderId { get; set; } = string.Empty;

    [JsonPropertyName("recommendedProviderName")]
    public string RecommendedProviderName { get; set; } = string.Empty;

    [JsonPropertyName("recommendationReason")]
    public string RecommendationReason { get; set; } = string.Empty;

    [JsonPropertyName("winningQuotation")]
    public ProviderQuotationDto WinningQuotation { get; set; } = new();

    [JsonPropertyName("allQuotations")]
    public List<ProviderQuotationDto> AllQuotations { get; set; } = new();

    [JsonPropertyName("bookingProposal")]
    public BookingDetailsDto BookingProposal { get; set; } = new();

    [JsonPropertyName("model")]
    public string Model { get; set; } = "gpt-4o-mini";

    [JsonPropertyName("latencyMs")]
    public long LatencyMs { get; set; }
}

public class ConfirmBookingRequest
{
    [JsonPropertyName("bookingReference")]
    public string? BookingReference { get; set; }

    [JsonPropertyName("providerId")]
    public string ProviderId { get; set; } = string.Empty;

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = string.Empty;

    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }

    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("location")]
    public string Location { get; set; } = string.Empty;

    [JsonPropertyName("schedule")]
    public string Schedule { get; set; } = string.Empty;

    [JsonPropertyName("price")]
    public decimal Price { get; set; }

    [JsonPropertyName("rateType")]
    public string? RateType { get; set; } = "Hourly";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Requested";
}

public class UpdateBookingStatusRequest
{
    [JsonPropertyName("bookingId")]
    public Guid? BookingId { get; set; }

    [JsonPropertyName("bookingReference")]
    public string? BookingReference { get; set; }

    [JsonPropertyName("newStatus")]
    public string NewStatus { get; set; } = "Active"; // Requested, Upcoming, Active, Completed, Cancelled

    [JsonPropertyName("schedule")]
    public string? Schedule { get; set; }

    [JsonPropertyName("price")]
    public decimal? Price { get; set; }
}

public class CreateQuotationRequest
{
    [JsonPropertyName("bookingReference")]
    public string? BookingReference { get; set; }

    [JsonPropertyName("providerId")]
    public string ProviderId { get; set; } = string.Empty;

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = string.Empty;

    [JsonPropertyName("customerId")]
    public string? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string? CustomerName { get; set; }

    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("location")]
    public string Location { get; set; } = string.Empty;

    [JsonPropertyName("schedule")]
    public string Schedule { get; set; } = string.Empty;

    [JsonPropertyName("price")]
    public decimal Price { get; set; }

    [JsonPropertyName("rateType")]
    public string? RateType { get; set; } = "Hourly";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Requested";
}

public class ProviderCounterBidRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("counterPrice")]
    public decimal CounterPrice { get; set; }

    [JsonPropertyName("rateType")]
    public string? RateType { get; set; }

    [JsonPropertyName("availableTime")]
    public string? AvailableTime { get; set; }

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("sender")]
    public string? Sender { get; set; } // "customer" or "provider"
}

public class CancelBookingRequest
{
    [JsonPropertyName("bookingReference")]
    public string BookingReference { get; set; } = string.Empty;

    [JsonPropertyName("reason")]
    public string? Reason { get; set; }
}

public class ProposalDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("proposalReference")]
    public string ProposalReference { get; set; } = string.Empty;

    [JsonPropertyName("customerId")]
    public Guid? CustomerId { get; set; }

    [JsonPropertyName("customerName")]
    public string CustomerName { get; set; } = "Customer";

    [JsonPropertyName("providerId")]
    public Guid? ProviderId { get; set; }

    [JsonPropertyName("providerName")]
    public string ProviderName { get; set; } = string.Empty;

    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("location")]
    public string Location { get; set; } = string.Empty;

    [JsonPropertyName("preferredSchedule")]
    public string PreferredSchedule { get; set; } = string.Empty;

    [JsonPropertyName("estimatedRate")]
    public decimal EstimatedRate { get; set; }

    [JsonPropertyName("rateType")]
    public string RateType { get; set; } = "Hourly";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Pending";

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; }
}

public class AcceptProposalRequest
{
    [JsonPropertyName("proposalReference")]
    public string ProposalReference { get; set; } = string.Empty;

    [JsonPropertyName("confirmedSchedule")]
    public string ConfirmedSchedule { get; set; } = string.Empty;

    [JsonPropertyName("confirmedPrice")]
    public decimal ConfirmedPrice { get; set; }

    [JsonPropertyName("rateType")]
    public string? RateType { get; set; }
}

public class DeclineProposalRequest
{
    [JsonPropertyName("proposalReference")]
    public string ProposalReference { get; set; } = string.Empty;

    [JsonPropertyName("reason")]
    public string? Reason { get; set; }
}
