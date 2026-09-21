using Microsoft.AspNetCore.Mvc;

namespace backend.Api.AI;

[ApiController]
[Route("api/agent/planning")]
public class PlanningAgentController : ControllerBase
{
    private readonly PlanningAgentService _planningService;
    private readonly ILogger<PlanningAgentController> _logger;

    public PlanningAgentController(
        PlanningAgentService planningService,
        ILogger<PlanningAgentController> logger)
    {
        _planningService = planningService;
        _logger = logger;
    }

    [HttpPost("analyze")]
    public async Task<IActionResult> Analyze([FromBody] PlanningAnalyzeRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Prompt))
        {
            return BadRequest(new { message = "Prompt cannot be empty." });
        }

        try
        {
            var result = await _planningService.AnalyzePromptAsync(request, ct);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred during planning analysis");
            return StatusCode(500, new { message = "An error occurred while processing your request with the planning agent." });
        }
    }
}
