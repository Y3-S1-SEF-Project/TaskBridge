using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using backend.Api.AI;
[HttpGet("all")]
public async Task<IActionResult> GetAllRequests(
    [FromQuery] string? status,
    [FromQuery] string? category,
    [FromQuery] string? search,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 20,
    CancellationToken ct = default)

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

[HttpGet("my")]
public async Task<IActionResult> GetMyRequests(
    [FromQuery] Guid? customerId,
    [FromQuery] string? status,
    [FromQuery] string? category,
    CancellationToken ct)
{
    try
    {
        var targetCustomerId = GetCurrentUserId() ?? customerId;

        if (!targetCustomerId.HasValue)
        {
            return BadRequest(new
            {
                message = "CustomerId is required to retrieve customer requests."
            });
        }

        var query = _db.ServiceRequests
            .AsNoTracking()
            .Where(x => x.CustomerId == targetCustomerId.Value);

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(x => x.Status.ToLower() == status.ToLower());
        }

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.Where(x => x.Category.ToLower() == category.ToLower());
        }

        var list = await query
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(ct);

        var result = list
            .Select(x => MapToResponse(x))
            .ToList();

        return Ok(result);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error fetching customer service requests");

        return StatusCode(500, new
        {
            message = "An error occurred while fetching your service requests."
        });
    }
}

}

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