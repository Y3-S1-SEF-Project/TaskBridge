using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using backend.Api.AI;

namespace TaskBridge.Api.Requests;

[ApiController]
[Route("api/requests")]
public class ServiceRequestsController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly PlanningAgentService _planningService;
    private readonly ILogger<ServiceRequestsController> _logger;

    public ServiceRequestsController(
        AuthDbContext db,
        PlanningAgentService planningService,
        ILogger<ServiceRequestsController> logger)
    {
        _db = db;
        _planningService = planningService;
        _logger = logger;
    }

}
/// <summary>
/// 2. Get a single service request with its AI breakdown and subtask checklist by ID.
/// </summary>
[HttpGet("{id:guid}")]
public async Task<IActionResult> GetRequestById(Guid id, CancellationToken ct)
{
    try
    {
        var entity = await _db.ServiceRequests
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == id, ct);

        if (entity == null)
        {
            return NotFound(new
            {
                message = $"Service request with ID '{id}' was not found."
            });
        }

        return Ok(MapToResponse(entity));
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error fetching service request {RequestId}", id);

        return StatusCode(500, new
        {
            message = "An error occurred while retrieving the service request."
        });
    }
}