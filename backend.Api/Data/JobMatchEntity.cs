namespace TaskBridge.Api.Data;

public sealed class JobMatchEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? ServiceRequestId { get; set; }
    public Guid? CustomerUserId { get; set; }
    public string CustomerName { get; set; } = "Customer";
    public string Category { get; set; } = string.Empty;
    public string ServiceTitle { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public int CandidatePoolCount { get; set; }
    public Guid? TopMatchedProviderId { get; set; }
    public string TopMatchedProviderName { get; set; } = string.Empty;
    public int TopMatchScore { get; set; }
    public string TopAiReason { get; set; } = string.Empty;

    /// <summary>
    /// Serialized JSON array of all top matched providers with scores, breakdown, and AI justifications
    /// </summary>
    public string MatchesJson { get; set; } = "[]";

    public long LatencyMs { get; set; }
    public int TokensUsed { get; set; }
    public string Model { get; set; } = "gpt-4o-mini";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
