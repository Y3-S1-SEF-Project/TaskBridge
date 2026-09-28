using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using TaskBridge.Api.Data;
using TaskBridge.Api.Requests;
using backend.Api.AI;
using Xunit;

namespace TaskBridge.Api.Tests;

public sealed class PlanningTests
{
    private readonly PlanningAgentService _planningService;

    public PlanningTests()
    {
        // Set up in-memory configuration with no API key to test deterministic fallback engine
        var inMemorySettings = new Dictionary<string, string?>
        {
            {"OpenAI:ApiKey", ""},
            {"OpenAI:Model", "gpt-4o-mini"}
        };

        IConfiguration configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(inMemorySettings)
            .Build();

        var httpClient = new HttpClient();
        _planningService = new PlanningAgentService(
            httpClient,
            configuration,
            NullLogger<PlanningAgentService>.Instance
        );
    }

    [Theory]
    [InlineData("My kitchen tap is leaking water under the sink", "Plumbing")]
    [InlineData("Need electrical socket repair in living room", "Electrical")]
    [InlineData("Living room wall painting required", "Painting")]
    [InlineData("AC servicing and gas refill needed", "HVAC")]
    public async Task PlanningAgent_CorrectlyCategorizesTrade_AndGeneratesChecklist(
        string prompt,
        string expectedCategory)
    {
        var request = new PlanningAnalyzeRequest
        {
            Prompt = prompt,
            UserLocation = "Colombo 05"
        };

        var result = await _planningService.AnalyzePromptAsync(request);

        Assert.NotNull(result);
        Assert.True(result.Success);
        Assert.Equal(expectedCategory, result.JobPlan.Category);
        Assert.NotEmpty(result.JobPlan.AcceptanceChecklist);
        Assert.True(
            result.JobPlan.AcceptanceChecklist.Count >= 3,
            "Checklist should contain at least 3 discrete subtasks."
        );
    }

    [Fact]
    public async Task PlanningAgent_DetectsMissingLocation_AndGeneratesClarificationQuestion()
    {
        var request = new PlanningAnalyzeRequest
        {
            Prompt = "Fix my bathroom drain blockage urgently",
            UserLocation = null
        };

        var result = await _planningService.AnalyzePromptAsync(request);

        Assert.NotNull(result);
        Assert.True(result.IsLocationMissing);
        Assert.Contains("location", result.MissingFields);
        Assert.False(string.IsNullOrWhiteSpace(result.ClarificationQuestion));
        Assert.Contains(
            "location",
            result.ClarificationQuestion,
            StringComparison.OrdinalIgnoreCase
        );
    }
}