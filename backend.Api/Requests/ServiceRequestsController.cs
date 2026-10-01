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

    /// <summary>
    /// 1. Create a new service request, trigger the Planning Agent for autonomous breakdown, and persist to PostgreSQL.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateRequest([FromBody] CreateServiceRequestDto dto, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(dto.Description))
        {
            return BadRequest(new { message = "Service request description or prompt cannot be empty." });
        }

        try
        {
            // Resolve Customer ID from authenticated session or DTO
            var currentUserId = GetCurrentUserId() ?? dto.CustomerId ?? Guid.NewGuid();

            // Run the Autonomous Planning Agent
            var analyzeReq = new PlanningAnalyzeRequest
            {
                Prompt = dto.Description,
                UserLocation = dto.Location,
                ScheduledDate = dto.ScheduledDate,
                ScheduledTime = dto.ScheduledTime,
                Budget = dto.EstimatedBudget
            };

            var aiResult = await _planningService.AnalyzePromptAsync(analyzeReq, ct);

            // Determine initial status based on AI missing info detection
            var initialStatus = (aiResult.IsLocationMissing || aiResult.MissingFields.Count > 0)
                ? "ClarificationRequired"
                : "ReadyForMatching";

            var entity = new ServiceRequestEntity
            {
                Id = Guid.NewGuid(),
                CustomerId = currentUserId,
                CustomerName = dto.CustomerName ?? "Customer",
                CustomerPhone = dto.CustomerPhone ?? string.Empty,
                Title = !string.IsNullOrWhiteSpace(dto.Title) ? dto.Title : aiResult.JobPlan.ServiceTitle,
                Category = !string.IsNullOrWhiteSpace(dto.Category) ? dto.Category : aiResult.JobPlan.Category,
                Description = dto.Description,
                Location = !string.IsNullOrWhiteSpace(dto.Location) ? dto.Location : (aiResult.JobPlan.Location ?? string.Empty),
                LocationAddress = dto.LocationAddress ?? aiResult.JobPlan.LocationAddress,
                EstimatedBudget = dto.EstimatedBudget ?? (aiResult.JobPlan.Budget.HasValue ? (decimal)aiResult.JobPlan.Budget.Value : null),
                ScheduledDate = !string.IsNullOrWhiteSpace(dto.ScheduledDate) ? dto.ScheduledDate : aiResult.JobPlan.ScheduledDate,
                ScheduledTime = !string.IsNullOrWhiteSpace(dto.ScheduledTime) ? dto.ScheduledTime : aiResult.JobPlan.ScheduledTime,
                Status = initialStatus,
                MediaUrlsJson = dto.MediaUrls != null && dto.MediaUrls.Count > 0 ? JsonSerializer.Serialize(dto.MediaUrls) : null,
                AiPlanJson = JsonSerializer.Serialize(aiResult.JobPlan),
                CreatedAt = DateTimeOffset.UtcNow
            };

            await _db.ServiceRequests.AddAsync(entity, ct);
            await _db.SaveChangesAsync(ct);

            var response = MapToResponse(entity, aiResult);
            return CreatedAtAction(nameof(GetRequestById), new { id = entity.Id }, response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating service request");
            return StatusCode(500, new { message = "An error occurred while creating the service request." });
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
            var entity = await _db.ServiceRequests.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
            if (entity == null)
            {
                return NotFound(new { message = $"Service request with ID '{id}' was not found." });
            }

            return Ok(MapToResponse(entity));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching service request {RequestId}", id);
            return StatusCode(500, new { message = "An error occurred while retrieving the service request." });
        }
    }

    /// <summary>
    /// 3. Get all service requests for the current customer with optional status filtering.
    /// </summary>
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
                return BadRequest(new { message = "CustomerId is required to retrieve customer requests." });
            }

            var query = _db.ServiceRequests.AsNoTracking().Where(x => x.CustomerId == targetCustomerId.Value);

            if (!string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(x => x.Status.ToLower() == status.ToLower());
            }

            if (!string.IsNullOrWhiteSpace(category))
            {
                query = query.Where(x => x.Category.ToLower() == category.ToLower());
            }

            var list = await query.OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
            var result = list.Select(x => MapToResponse(x)).ToList();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching customer service requests");
            return StatusCode(500, new { message = "An error occurred while fetching your service requests." });
        }
    }

    /// <summary>
    /// 4. Admin / Staff endpoint: List all platform service requests with search, filtering, and pagination for React Web.
    /// </summary>
    [HttpGet("all")]
    public async Task<IActionResult> GetAllRequests(
        [FromQuery] string? status,
        [FromQuery] string? category,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        try
        {
            var query = _db.ServiceRequests.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(x => x.Status.ToLower() == status.ToLower());
            }

            if (!string.IsNullOrWhiteSpace(category))
            {
                query = query.Where(x => x.Category.ToLower() == category.ToLower());
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.ToLower();
                query = query.Where(x => x.Title.ToLower().Contains(s) ||
                                         x.Description.ToLower().Contains(s) ||
                                         x.CustomerName.ToLower().Contains(s) ||
                                         x.Location.ToLower().Contains(s));
            }

            var totalCount = await query.CountAsync(ct);
            var items = await query.OrderByDescending(x => x.CreatedAt)
                                   .Skip((page - 1) * pageSize)
                                   .Take(pageSize)
                                   .ToListAsync(ct);

            return Ok(new
            {
                totalCount,
                page,
                pageSize,
                totalPages = (int)Math.Ceiling(totalCount / (double)pageSize),
                items = items.Select(x => MapToResponse(x)).ToList()
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching all service requests for admin dashboard");
            return StatusCode(500, new { message = "An error occurred while retrieving service requests." });
        }
    }

    /// <summary>
    /// 5. Business-specific operation: Submit customer answers to Planning Agent clarification questions to unlock provider matching.
    /// </summary>
    [HttpPost("{id:guid}/clarify")]
    public async Task<IActionResult> SubmitClarification(Guid id, [FromBody] SubmitClarificationDto dto, CancellationToken ct)
    {
        try
        {
            var entity = await _db.ServiceRequests.FirstOrDefaultAsync(x => x.Id == id, ct);
            if (entity == null)
            {
                return NotFound(new { message = $"Service request with ID '{id}' was not found." });
            }

            if (entity.Status == "Cancelled" || entity.Status == "Completed")
            {
                return BadRequest(new { message = $"Cannot clarify request in '{entity.Status}' state." });
            }

            // Update details from clarification
            if (!string.IsNullOrWhiteSpace(dto.Location))
            {
                entity.Location = dto.Location;
            }
            if (!string.IsNullOrWhiteSpace(dto.LocationAddress))
            {
                entity.LocationAddress = dto.LocationAddress;
            }
            if (!string.IsNullOrWhiteSpace(dto.ScheduledDate))
            {
                entity.ScheduledDate = dto.ScheduledDate;
            }
            if (!string.IsNullOrWhiteSpace(dto.ScheduledTime))
            {
                entity.ScheduledTime = dto.ScheduledTime;
            }
            if (dto.Budget.HasValue && dto.Budget.Value > 0)
            {
                entity.EstimatedBudget = dto.Budget.Value;
            }

            if (dto.Answers != null && dto.Answers.Count > 0)
            {
                entity.ClarificationAnswersJson = JsonSerializer.Serialize(dto.Answers);
            }

            // Transition status to ReadyForMatching once clarified
            entity.Status = "ReadyForMatching";
            entity.UpdatedAt = DateTimeOffset.UtcNow;

            await _db.SaveChangesAsync(ct);

            return Ok(new
            {
                success = true,
                message = "Clarification submitted successfully. Service request is now ready for provider matching.",
                request = MapToResponse(entity)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error submitting clarification for request {RequestId}", id);
            return StatusCode(500, new { message = "An error occurred while submitting clarification." });
        }
    }

    /// <summary>
    /// 6. Business-specific operation: Cancel an open service request with state-transition validation and audit reason.
    /// </summary>
    [HttpPut("{id:guid}/cancel")]
    public async Task<IActionResult> CancelRequest(Guid id, [FromBody] CancelServiceRequestDto dto, CancellationToken ct)
    {
        try
        {
            var entity = await _db.ServiceRequests.FirstOrDefaultAsync(x => x.Id == id, ct);
            if (entity == null)
            {
                return NotFound(new { message = $"Service request with ID '{id}' was not found." });
            }

            if (entity.Status == "Completed")
            {
                return BadRequest(new { message = "Cannot cancel a completed service request." });
            }

            if (entity.Status == "Active")
            {
                return BadRequest(new { message = "Technician is actively working on-site. Please use the dispute workflow instead." });
            }

            entity.Status = "Cancelled";
            entity.CancellationReason = string.IsNullOrWhiteSpace(dto.Reason) ? "Cancelled by user" : dto.Reason;
            entity.UpdatedAt = DateTimeOffset.UtcNow;

            await _db.SaveChangesAsync(ct);

            return Ok(new
            {
                success = true,
                message = $"Service request '{id}' has been cancelled successfully.",
                request = MapToResponse(entity)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling service request {RequestId}", id);
            return StatusCode(500, new { message = "An error occurred while cancelling the service request." });
        }
    }

    // Helper: Map Entity to Response DTO
    private static ServiceRequestResponseDto MapToResponse(ServiceRequestEntity entity, PlanningAnalyzeResponse? aiResult = null)
    {
        var mediaUrls = !string.IsNullOrWhiteSpace(entity.MediaUrlsJson)
            ? JsonSerializer.Deserialize<List<string>>(entity.MediaUrlsJson) ?? []
            : new List<string>();

        JobPlanDetails? parsedPlan = null;
        if (!string.IsNullOrWhiteSpace(entity.AiPlanJson))
        {
            try
            {
                parsedPlan = JsonSerializer.Deserialize<JobPlanDetails>(entity.AiPlanJson);
            }
            catch { }
        }

        var checklist = parsedPlan?.AcceptanceChecklist ?? aiResult?.JobPlan?.AcceptanceChecklist ?? [];
        var isLocMissing = string.IsNullOrWhiteSpace(entity.Location);
        var missingFields = new List<string>();
        if (isLocMissing) missingFields.Add("location");
        if (!entity.EstimatedBudget.HasValue || entity.EstimatedBudget <= 0) missingFields.Add("budget");

        return new ServiceRequestResponseDto
        {
            Id = entity.Id,
            CustomerId = entity.CustomerId,
            CustomerName = entity.CustomerName,
            CustomerPhone = entity.CustomerPhone,
            Title = entity.Title,
            Category = entity.Category,
            Description = entity.Description,
            Location = entity.Location,
            LocationAddress = entity.LocationAddress,
            EstimatedBudget = entity.EstimatedBudget,
            ScheduledDate = entity.ScheduledDate,
            ScheduledTime = entity.ScheduledTime,
            Status = entity.Status,
            MediaUrls = mediaUrls,
            AiPlan = parsedPlan ?? aiResult?.JobPlan,
            AcceptanceChecklist = checklist,
            ClarificationQuestion = aiResult?.ClarificationQuestion ?? (isLocMissing ? "Where do you need the service? We need your location to find nearby specialists." : null),
            IsLocationMissing = isLocMissing,
            MissingFields = missingFields,
            CancellationReason = entity.CancellationReason,
            CreatedAt = entity.CreatedAt,
            UpdatedAt = entity.UpdatedAt
        };
    }

    private Guid? GetCurrentUserId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(claim, out var guid) ? guid : null;
    }
}
