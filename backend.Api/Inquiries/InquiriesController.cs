using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using TaskBridge.Api.Notifications;

namespace TaskBridge.Api.Inquiries;

[ApiController]
[Route("api/inquiries")]
public sealed class InquiriesController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly INotificationService _notificationService;
    private readonly ILogger<InquiriesController> _logger;

    public InquiriesController(
        AuthDbContext db,
        INotificationService notificationService,
        ILogger<InquiriesController> logger)
    {
        _db = db;
        _notificationService = notificationService;
        _logger = logger;
    }

    /// <summary>
    /// User creates an inquiry (system issue, question, etc.)
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateInquiry([FromBody] CreateInquiryRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Subject))
            return BadRequest(new { error = "Subject is required." });

        if (string.IsNullOrWhiteSpace(request.Message))
            return BadRequest(new { error = "Message description is required." });

        // Lookup user details if possible
        string? userEmail = null;
        string? userPhone = null;
        string userName = request.UserName ?? "User";

        if (request.UserId.HasValue)
        {
            var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == request.UserId.Value, ct);
            if (user != null)
            {
                userEmail = user.Email;
                userPhone = user.Phone;
                if (!string.IsNullOrWhiteSpace(user.FullName))
                    userName = user.FullName;
            }
        }

        var inquiry = new InquiryEntity
        {
            Id = Guid.NewGuid(),
            InquiryReference = $"INQ-{Random.Shared.Next(1000, 9999)}",
            UserId = request.UserId,
            UserName = userName,
            UserEmail = userEmail,
            UserPhone = userPhone,
            UserRole = string.IsNullOrWhiteSpace(request.UserRole) ? "Customer" : request.UserRole,
            Subject = request.Subject.Trim(),
            Category = string.IsNullOrWhiteSpace(request.Category) ? "System Issue / Bug" : request.Category.Trim(),
            Message = request.Message.Trim(),
            Priority = string.IsNullOrWhiteSpace(request.Priority) ? "Normal" : request.Priority.Trim(),
            Status = "Open",
            AttachmentUrlsJson = request.AttachmentUrls != null && request.AttachmentUrls.Count > 0
                ? JsonSerializer.Serialize(request.AttachmentUrls)
                : null,
            CreatedAt = DateTime.UtcNow
        };

        _db.Inquiries.Add(inquiry);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("📩 [Inquiries] New inquiry created: {Ref} by {User}", inquiry.InquiryReference, inquiry.UserName);

        // Notify Admins
        try
        {
            await _notificationService.SendNotificationAsync(new CreateNotificationDto
            {
                TargetRole = "admin",
                Title = $"New Support Inquiry #{inquiry.InquiryReference}",
                Message = $"{inquiry.UserName} reported: \"{inquiry.Subject}\" ({inquiry.Category})",
                Type = "InquiryCreated",
                ReferenceId = inquiry.InquiryReference,
                ReferenceType = "Inquiry",
                Metadata = new { inquiry.InquiryReference, inquiry.Category, inquiry.Priority }
            }, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to broadcast inquiry notification to admins: {Msg}", ex.Message);
        }

        return CreatedAtAction(nameof(GetInquiryByIdOrRef), new { idOrRef = inquiry.InquiryReference }, MapToDto(inquiry));
    }

    /// <summary>
    /// Gets inquiries for the current user or all inquiries if admin
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<InquiryResponseDto>>> GetUserInquiries(
        [FromQuery] Guid? userId,
        [FromQuery] string? search,
        CancellationToken ct)
    {
        var query = _db.Inquiries.AsNoTracking().AsQueryable();

        if (userId.HasValue)
        {
            query = query.Where(i => i.UserId == userId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(i =>
                i.InquiryReference.ToLower().Contains(s) ||
                i.Subject.ToLower().Contains(s) ||
                i.UserName.ToLower().Contains(s) ||
                i.Category.ToLower().Contains(s));
        }

        var list = await query
            .OrderByDescending(i => i.CreatedAt)
            .Take(100)
            .ToListAsync(ct);

        return Ok(list.Select(MapToDto).ToList());
    }

    /// <summary>
    /// Gets a single inquiry by ID or reference
    /// </summary>
    [HttpGet("{idOrRef}")]
    public async Task<ActionResult<InquiryResponseDto>> GetInquiryByIdOrRef(string idOrRef, CancellationToken ct)
    {
        InquiryEntity? inquiry = null;
        if (Guid.TryParse(idOrRef, out var id))
        {
            inquiry = await _db.Inquiries.AsNoTracking().FirstOrDefaultAsync(i => i.Id == id, ct);
        }

        inquiry ??= await _db.Inquiries.AsNoTracking().FirstOrDefaultAsync(i =>
            i.InquiryReference.ToLower() == idOrRef.Trim().ToLower(), ct);

        if (inquiry == null)
            return NotFound(new { error = $"Inquiry '{idOrRef}' was not found." });

        return Ok(MapToDto(inquiry));
    }

    /// <summary>
    /// Admin endpoint to fetch summary and list of inquiries
    /// </summary>
    [HttpGet("/api/admin/inquiries")]
    public async Task<ActionResult<InquiriesSummaryResponseDto>> GetAdminInquiries(
        [FromQuery] string? status,
        [FromQuery] string? priority,
        [FromQuery] string? search,
        CancellationToken ct)
    {
        var query = _db.Inquiries.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && status != "All")
        {
            query = query.Where(i => i.Status.ToLower() == status.Trim().ToLower());
        }

        if (!string.IsNullOrWhiteSpace(priority) && priority != "All")
        {
            query = query.Where(i => i.Priority.ToLower() == priority.Trim().ToLower());
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(i =>
                i.InquiryReference.ToLower().Contains(s) ||
                i.Subject.ToLower().Contains(s) ||
                i.UserName.ToLower().Contains(s) ||
                i.Category.ToLower().Contains(s));
        }

        var allItems = await query.OrderByDescending(i => i.CreatedAt).ToListAsync(ct);

        var total = allItems.Count;
        var open = allItems.Count(i => i.Status == "Open" || i.Status == "InProgress");
        var responded = allItems.Count(i => i.Status == "Responded");
        var resolved = allItems.Count(i => i.Status == "Resolved");

        return Ok(new InquiriesSummaryResponseDto(
            allItems.Select(MapToDto).ToList(),
            total,
            open,
            responded,
            resolved
        ));
    }

    /// <summary>
    /// Admin responds to an inquiry
    /// </summary>
    [HttpPost("/api/admin/inquiries/{id:guid}/respond")]
    public async Task<IActionResult> RespondInquiry(
        Guid id,
        [FromBody] AdminRespondInquiryRequest request,
        CancellationToken ct)
    {
        var inquiry = await _db.Inquiries.FirstOrDefaultAsync(i => i.Id == id, ct);
        if (inquiry == null)
            return NotFound(new { error = "Inquiry not found." });

        if (string.IsNullOrWhiteSpace(request.ResponseMessage))
            return BadRequest(new { error = "Response message cannot be empty." });

        inquiry.AdminResponse = request.ResponseMessage.Trim();
        inquiry.RespondedByAdminName = string.IsNullOrWhiteSpace(request.AdminName) ? "Admin Support" : request.AdminName.Trim();
        inquiry.RespondedAt = DateTime.UtcNow;
        inquiry.Status = string.IsNullOrWhiteSpace(request.Status) ? "Responded" : request.Status.Trim();
        inquiry.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("💬 [Inquiries] Admin responded to {Ref} ({Status})", inquiry.InquiryReference, inquiry.Status);

        // Notify user if UserId is present
        if (inquiry.UserId.HasValue)
        {
            try
            {
                await _notificationService.SendNotificationAsync(new CreateNotificationDto
                {
                    UserId = inquiry.UserId.Value,
                    UserName = inquiry.UserName,
                    TargetRole = inquiry.UserRole.ToLowerInvariant(),
                    Title = $"Response on Inquiry #{inquiry.InquiryReference}",
                    Message = $"Admin responded: \"{inquiry.AdminResponse}\"",
                    Type = "InquiryResponse",
                    ReferenceId = inquiry.InquiryReference,
                    ReferenceType = "Inquiry",
                    Metadata = new { inquiry.InquiryReference, inquiry.Status }
                }, ct);
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Failed to notify user about inquiry response: {Msg}", ex.Message);
            }
        }

        return Ok(MapToDto(inquiry));
    }

    /// <summary>
    /// Deletes an inquiry (user or admin)
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteInquiry(Guid id, CancellationToken ct)
    {
        var inquiry = await _db.Inquiries.FirstOrDefaultAsync(i => i.Id == id, ct);
        if (inquiry == null)
            return NotFound(new { error = "Inquiry not found." });

        _db.Inquiries.Remove(inquiry);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("🗑️ [Inquiries] Inquiry deleted: {Ref} ({Id})", inquiry.InquiryReference, inquiry.Id);
        return Ok(new { success = true, message = $"Inquiry {inquiry.InquiryReference} was successfully deleted." });
    }

    /// <summary>
    /// Admin endpoint to delete an inquiry
    /// </summary>
    [HttpDelete("/api/admin/inquiries/{id:guid}")]
    public async Task<IActionResult> AdminDeleteInquiry(Guid id, CancellationToken ct)
    {
        return await DeleteInquiry(id, ct);
    }

    private static InquiryResponseDto MapToDto(InquiryEntity i)
    {
        List<string> attachments = [];
        if (!string.IsNullOrWhiteSpace(i.AttachmentUrlsJson))
        {
            try
            {
                attachments = JsonSerializer.Deserialize<List<string>>(i.AttachmentUrlsJson) ?? [];
            }
            catch { }
        }

        return new InquiryResponseDto(
            i.Id,
            i.InquiryReference,
            i.UserId,
            i.UserName,
            i.UserEmail,
            i.UserPhone,
            i.UserRole,
            i.Subject,
            i.Category,
            i.Message,
            attachments,
            i.Priority,
            i.Status,
            i.AdminResponse,
            i.RespondedByAdminName,
            i.RespondedAt,
            i.CreatedAt,
            i.UpdatedAt
        );
    }
}
