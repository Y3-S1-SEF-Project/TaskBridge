namespace backend.Api.AI;

public sealed class ProposalEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string ProposalReference { get; set; } = string.Empty; // e.g. PR-1026
    public Guid? CustomerId { get; set; }
    public string CustomerName { get; set; } = "Customer";
    public Guid? ProviderId { get; set; }
    public string ProviderName { get; set; } = string.Empty;
    public string ServiceTitle { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public string PreferredSchedule { get; set; } = string.Empty; // e.g. Tomorrow Afternoon (12 PM - 5 PM)
    public decimal EstimatedRate { get; set; } // Provider hourly rate at time of proposal
    public string RateType { get; set; } = "Hourly"; // Hourly or Fixed
    public string? Notes { get; set; }
    public string Status { get; set; } = "Pending"; // Pending, Accepted, Declined, Cancelled
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}
