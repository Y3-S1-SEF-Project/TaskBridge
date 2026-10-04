namespace TaskBridge.Api.Data;

public sealed class ServiceRequestEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerPhone { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public string? LocationAddress { get; set; }
    public decimal? EstimatedBudget { get; set; }
    public string ScheduledDate { get; set; } = string.Empty;
    public string ScheduledTime { get; set; } = string.Empty;

    /// <summary>
    /// Status lifecycle: ClarificationRequired, ReadyForMatching, Matching, Booked, Completed, Cancelled
    /// </summary>
    public string Status { get; set; } = "ClarificationRequired";

    /// <summary>
    /// JSON array of uploaded problem/damage evidence photo URLs
    /// </summary>
    public string? MediaUrlsJson { get; set; }

    /// <summary>
    /// Structured AI-generated plan containing checklist, required tools, and safety risks
    /// </summary>
    public string? AiPlanJson { get; set; }

    /// <summary>
    /// Customer responses to Planning Agent dynamic clarification questions
    /// </summary>
    public string? ClarificationAnswersJson { get; set; }

    /// <summary>
    /// Serialized JSON array of matched provider recommendations from Agent 2 (Matching Agent)
    /// </summary>
    public string? MatchedProvidersJson { get; set; }

    public string? CancellationReason { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}
