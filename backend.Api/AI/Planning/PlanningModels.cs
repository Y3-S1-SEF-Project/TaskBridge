using System.Text.Json.Serialization;

namespace backend.Api.AI;

public class PlanningAnalyzeRequest
{
    [JsonPropertyName("prompt")]
    public string Prompt { get; set; } = string.Empty;

    [JsonPropertyName("userLocation")]
    public string? UserLocation { get; set; }

    [JsonPropertyName("scheduledDate")]
    public string? ScheduledDate { get; set; }

    [JsonPropertyName("scheduledTime")]
    public string? ScheduledTime { get; set; }

    [JsonPropertyName("budget")]
    public decimal? Budget { get; set; }

    [JsonPropertyName("userId")]
    public int? UserId { get; set; }
}

public class JobPlanDetails
{
    [JsonPropertyName("serviceTitle")]
    public string ServiceTitle { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("location")]
    public string? Location { get; set; }

    [JsonPropertyName("locationAddress")]
    public string? LocationAddress { get; set; }

    [JsonPropertyName("scheduledDate")]
    public string ScheduledDate { get; set; } = string.Empty;

    [JsonPropertyName("scheduledTime")]
    public string ScheduledTime { get; set; } = string.Empty;

    [JsonPropertyName("budget")]
    public decimal? Budget { get; set; }

    [JsonPropertyName("budgetDisplay")]
    public string BudgetDisplay { get; set; } = string.Empty;

    [JsonPropertyName("acceptanceChecklist")]
    public List<string> AcceptanceChecklist { get; set; } = new();
}

public class ReasoningStepItem
{
    [JsonPropertyName("stepKey")]
    public string StepKey { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("subtitle")]
    public string Subtitle { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "pending"; // completed, in_progress, pending
}

public class PlanningAnalyzeResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; } = true;

    [JsonPropertyName("isLocationMissing")]
    public bool IsLocationMissing { get; set; }

    [JsonPropertyName("missingFields")]
    public List<string> MissingFields { get; set; } = new();

    [JsonPropertyName("clarificationQuestion")]
    public string? ClarificationQuestion { get; set; }

    [JsonPropertyName("jobPlan")]
    public JobPlanDetails JobPlan { get; set; } = new();

    [JsonPropertyName("progressSteps")]
    public List<ReasoningStepItem> ProgressSteps { get; set; } = new();

    [JsonPropertyName("latencyMs")]
    public long LatencyMs { get; set; }

    [JsonPropertyName("tokensUsed")]
    public int TokensUsed { get; set; }

    [JsonPropertyName("model")]
    public string Model { get; set; } = "gpt-4o-mini";
}
