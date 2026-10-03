using Microsoft.AspNetCore.Mvc;

namespace backend.Api.AI;

[ApiController]
[Route("api/agent/matching")]
public class MatchingAgentController : ControllerBase
{
    private readonly MatchingAgentService _matchingService;
    private readonly ILogger<MatchingAgentController> _logger;

    public MatchingAgentController(
        MatchingAgentService matchingService,
        ILogger<MatchingAgentController> logger)
    {
        _matchingService = matchingService;
        _logger = logger;
    }

    [HttpPost("match")]
    public async Task<IActionResult> Match([FromBody] MatchingRequest request, CancellationToken ct)
    {
        try
        {
            var result = await _matchingService.MatchProvidersAsync(request, ct);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred during matching analysis");
            return StatusCode(500, new { message = "An error occurred while matching providers." });
        }
    }

    [HttpGet("history")]
    public async Task<IActionResult> GetMatchHistory([FromQuery] string? customerUserId, CancellationToken ct)
    {
        try
        {
            var history = await _matchingService.GetMatchHistoryAsync(customerUserId, ct);
            return Ok(history);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred retrieving matching history");
            return StatusCode(500, new { message = "An error occurred while retrieving matching history." });
        }
    }
}
