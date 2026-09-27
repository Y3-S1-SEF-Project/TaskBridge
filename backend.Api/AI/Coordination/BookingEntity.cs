namespace backend.Api.AI;

public sealed class BookingEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string BookingReference { get; set; } = string.Empty; // e.g. TB-1042
    public Guid? ProposalId { get; set; } // Reference to originating proposal
    public Guid? CustomerId { get; set; }
    public string CustomerName { get; set; } = "Customer";
    public Guid? ProviderId { get; set; }
    public string ProviderName { get; set; } = string.Empty;
    public string ServiceTitle { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public string Schedule { get; set; } = string.Empty; // e.g. 17 Sep · 4:00 PM · Colombo 05
    public decimal Price { get; set; }
    public string RateType { get; set; } = "Hourly"; // Hourly or Fixed
    public string? Notes { get; set; }
    public string Status { get; set; } = "Upcoming"; // Upcoming, Active, Completed, Cancelled
    public DateTimeOffset? StartedAt { get; set; }
    public DateTimeOffset? EndedAt { get; set; }
    public int? DurationMinutes { get; set; }
    public decimal? FinalCalculatedPrice { get; set; }
    public string? BeforePhotoUrl { get; set; }
    public string? AgreedChecklist { get; set; } // JSON array of checklist items from Agent 1
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}
