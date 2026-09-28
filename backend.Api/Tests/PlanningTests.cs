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
        _planningService = new PlanningAgentService(httpClient, configuration, NullLogger<PlanningAgentService>.Instance);
    }

    [Theory]
    [InlineData("My kitchen tap is leaking water under the sink", "Plumbing")]
    [InlineData("Need electrical socket repair in living room", "Electrical")]
    [InlineData("Living room wall painting required", "Painting")]
    [InlineData("AC servicing and gas refill needed", "HVAC")]
    public async Task PlanningAgent_CorrectlyCategorizesTrade_AndGeneratesChecklist(string prompt, string expectedCategory)
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
        Assert.True(result.JobPlan.AcceptanceChecklist.Count >= 3, "Checklist should contain at least 3 discrete subtasks.");
    }

    [Fact]
    public async Task PlanningAgent_DetectsMissingLocation_AndGeneratesClarificationQuestion()
    {
        var request = new PlanningAnalyzeRequest
        {
            Prompt = "Fix my bathroom drain blockage urgently",
            UserLocation = null // Omitted location
        };

        var result = await _planningService.AnalyzePromptAsync(request);

        Assert.NotNull(result);
        Assert.True(result.IsLocationMissing);
        Assert.Contains("location", result.MissingFields);
        Assert.False(string.IsNullOrWhiteSpace(result.ClarificationQuestion));
        Assert.Contains("location", result.ClarificationQuestion, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PlanningAgent_EnforcesAntiHallucination_WhenBudgetOmitted()
    {
        var request = new PlanningAnalyzeRequest
        {
            Prompt = "Fix leaking water pipe near main valve tomorrow morning",
            UserLocation = "Colombo 03"
        };

        var result = await _planningService.AnalyzePromptAsync(request);

        Assert.NotNull(result);
        Assert.Null(result.JobPlan.Budget);
        Assert.Equal("Budget not specified", result.JobPlan.BudgetDisplay);
        Assert.Contains("budget", result.MissingFields);
    }

    [Fact]
    public async Task PlanningAgent_OfflineFallback_ProducesValidStructuredSchema()
    {
        var request = new PlanningAnalyzeRequest
        {
            Prompt = "Clean full 3 bedroom house before the weekend",
            UserLocation = "Nugegoda"
        };

        var result = await _planningService.AnalyzePromptAsync(request);

        Assert.NotNull(result);
        Assert.True(result.Model == "rule-based-fallback" || result.Model == "local-demo-fallback" || result.Model.Contains("gpt"));
        Assert.Equal(4, result.ProgressSteps.Count);
        Assert.False(string.IsNullOrWhiteSpace(result.JobPlan.ServiceTitle));
    }

    [Fact]
    public async Task Controller_RejectsEmptyDescription_WithBadRequest()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: "Test_Db_EmptyPrompt_" + Guid.NewGuid())
            .Options;

        await using var db = new AuthDbContext(options);
        var controller = new ServiceRequestsController(db, _planningService, NullLogger<ServiceRequestsController>.Instance);

        var dto = new CreateServiceRequestDto
        {
            Description = "   " // Empty whitespace prompt
        };

        var response = await controller.CreateRequest(dto, CancellationToken.None);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(response);
        Assert.Equal(400, badRequestResult.StatusCode);
    }

    [Fact]
    public async Task Controller_CancelsOpenRequest_AndUpdatesAuditReason()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: "Test_Db_Cancel_" + Guid.NewGuid())
            .Options;

        await using var db = new AuthDbContext(options);
        var controller = new ServiceRequestsController(db, _planningService, NullLogger<ServiceRequestsController>.Instance);

        // Seed an open service request
        var requestId = Guid.NewGuid();
        var entity = new ServiceRequestEntity
        {
            Id = requestId,
            CustomerId = Guid.NewGuid(),
            CustomerName = "Kasun Perera",
            Title = "Sink Pipe Repair",
            Category = "Plumbing",
            Description = "Fix leaking sink pipe",
            Location = "Colombo 05",
            Status = "ReadyForMatching",
            CreatedAt = DateTimeOffset.UtcNow
        };
        await db.ServiceRequests.AddAsync(entity);
        await db.SaveChangesAsync();

        // Perform cancellation
        var cancelDto = new CancelServiceRequestDto
        {
            Reason = "Fixed the issue myself with Teflon tape"
        };

        var response = await controller.CancelRequest(requestId, cancelDto, CancellationToken.None);

        var okResult = Assert.IsType<OkObjectResult>(response);
        Assert.Equal(200, okResult.StatusCode);

        // Verify database state
        var updated = await db.ServiceRequests.FindAsync(requestId);
        Assert.NotNull(updated);
        Assert.Equal("Cancelled", updated.Status);
        Assert.Equal("Fixed the issue myself with Teflon tape", updated.CancellationReason);
        Assert.NotNull(updated.UpdatedAt);
    }
}
