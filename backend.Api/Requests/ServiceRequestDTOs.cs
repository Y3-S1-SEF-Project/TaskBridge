using System.Text.Json.Serialization;
using backend.Api.AI;

namespace TaskBridge.Api.Requests;

public sealed class CreateServiceRequestDto
{
    public string? Title { get; set; }
    public string? Category { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? Location { get; set; }
    public string? LocationAddress { get; set; }
    public decimal? EstimatedBudget { get; set; }
    public string? ScheduledDate { get; set; }
    public string? ScheduledTime { get; set; }
    public List<string>? MediaUrls { get; set; }
    public Guid? CustomerId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
}

public sealed class SubmitClarificationDto
{
    public string? Location { get; set; }
    public string? LocationAddress { get; set; }
    public string? ScheduledDate { get; set; }
    public string? ScheduledTime { get; set; }
    public decimal? Budget { get; set; }
    public Dictionary<string, string>? Answers { get; set; }
}

public sealed class CancelServiceRequestDto
{
    public string Reason { get; set; } = string.Empty;
}