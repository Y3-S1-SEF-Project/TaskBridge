using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using TaskBridge.Api.Notifications;

namespace TaskBridge.Api.Disputes;

[ApiController]
[Route("api/disputes")]
public sealed class DisputesController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly INotificationService _notificationService;
    private readonly ILogger<DisputesController> _logger;

    public DisputesController(
        AuthDbContext db,
        INotificationService notificationService,
        ILogger<DisputesController> logger)
    {
        _db = db;
        _notificationService = notificationService;
        _logger = logger;
    }

    /// <summary>
    /// Creates a formal dispute against a job completion. Marks booking and completion as 'Disputed'.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateDispute([FromBody] CreateDisputeRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        if (string.IsNullOrWhiteSpace(request.Description))
            return BadRequest(new { error = "Please provide details about the issue." });

        var altRef = request.BookingReference.StartsWith("TB-")
            ? request.BookingReference.Replace("TB-", "PR-")
            : request.BookingReference.Replace("PR-", "TB-");

        var booking = await _db.Bookings
            .FirstOrDefaultAsync(b => b.BookingReference == request.BookingReference || b.BookingReference == altRef, ct);

        var completion = await _db.JobCompletions
            .FirstOrDefaultAsync(c => c.BookingReference == request.BookingReference || c.BookingReference == altRef, ct);

        // Extract photo proofs
        var beforePhotos = new List<string>();
        var afterPhotos = new List<string>();

        if (completion != null)
        {
            if (!string.IsNullOrWhiteSpace(completion.BeforePhotoUrl))
            {
                if (completion.BeforePhotoUrl.StartsWith("["))
                {
                    try { beforePhotos = JsonSerializer.Deserialize<List<string>>(completion.BeforePhotoUrl) ?? new(); } catch { }
                }
                else
                {
                    beforePhotos.Add(completion.BeforePhotoUrl);
                }
            }

            if (!string.IsNullOrWhiteSpace(completion.AfterPhotoUrls))
            {
                try { afterPhotos = JsonSerializer.Deserialize<List<string>>(completion.AfterPhotoUrls) ?? new(); } catch { }
            }
        }
        else if (booking != null && !string.IsNullOrWhiteSpace(booking.BeforePhotoUrl))
        {
            beforePhotos.Add(booking.BeforePhotoUrl);
        }

        var randSuffix = Random.Shared.Next(1000, 9999);
        var disputeRef = $"DSP-{randSuffix}";

        // Mark the job as NOT finished (Disputed)
        if (booking != null)
        {
            booking.Status = "Disputed";
            booking.UpdatedAt = DateTimeOffset.UtcNow;
        }

        if (completion != null)
        {
            completion.Status = "Disputed";
            completion.UpdatedAt = DateTimeOffset.UtcNow;
        }

        var customerId = booking?.CustomerId ?? (Guid.TryParse(request.CustomerId, out var cid) ? cid : null);
        var customerName = booking?.CustomerName ?? request.CustomerName ?? "Customer";

        string? customerPhone = null;
        if (customerId.HasValue)
        {
            var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == customerId.Value, ct);
            customerPhone = user?.Phone;
        }

        var dispute = new DisputeEntity
        {
            Id = Guid.NewGuid(),
            DisputeReference = disputeRef,
            BookingId = booking?.Id,
            BookingReference = booking?.BookingReference ?? request.BookingReference,
            CustomerId = customerId,
            CustomerName = customerName,
            CustomerPhone = customerPhone,
            ProviderId = booking?.ProviderId ?? completion?.ProviderId,
            ProviderName = booking?.ProviderName ?? completion?.ProviderName ?? "Provider",
            ServiceTitle = booking?.ServiceTitle ?? completion?.ServiceTitle ?? "Service Job",
            Category = booking?.Category ?? completion?.Category ?? "General",
            FeeAmount = completion?.CalculatedPrice ?? booking?.FinalCalculatedPrice ?? booking?.Price ?? 0m,
            ReasonCategory = string.IsNullOrWhiteSpace(request.ReasonCategory) ? "Service Quality" : request.ReasonCategory,
            Description = request.Description.Trim(),
            DesiredResolution = string.IsNullOrWhiteSpace(request.DesiredResolution) ? "Admin Mediation" : request.DesiredResolution,
            BeforePhotoUrlsJson = JsonSerializer.Serialize(beforePhotos),
            AfterPhotoUrlsJson = JsonSerializer.Serialize(afterPhotos),
            CustomerEvidencePhotoUrlsJson = request.EvidencePhotoUrls != null && request.EvidencePhotoUrls.Count > 0
                ? JsonSerializer.Serialize(request.EvidencePhotoUrls)
                : null,
            Status = "PendingAdminReview",
            CreatedAt = DateTimeOffset.UtcNow
        };

        _db.Disputes.Add(dispute);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("Dispute {DisputeRef} created for Booking {BookingRef} by {Customer}", disputeRef, dispute.BookingReference, dispute.CustomerName);

        // Notify Customer
        try
        {
            await _notificationService.SendNotificationAsync(new CreateNotificationDto
            {
                UserId = dispute.CustomerId,
                UserName = dispute.CustomerName,
                TargetRole = "customer",
                Title = "Dispute Raised with Admin",
                Message = $"Your dispute #{dispute.DisputeReference} for {dispute.ServiceTitle} has been submitted. The job is on freeze pending admin review.",
                Type = "DisputeOpened",
                ReferenceId = dispute.DisputeReference,
                ReferenceType = "Dispute",
                Metadata = new { dispute.DisputeReference, dispute.BookingReference }
            }, ct);
        }
        catch { }

        // Notify Provider
        try
        {
            await _notificationService.SendNotificationAsync(new CreateNotificationDto
            {
                UserId = dispute.ProviderId,
                UserName = dispute.ProviderName,
                TargetRole = "provider",
                Title = "Job Under Dispute",
                Message = $"{dispute.CustomerName} raised a dispute on #{dispute.BookingReference} ({dispute.ReasonCategory}). The job is held under admin mediation.",
                Type = "DisputeOpened",
                ReferenceId = dispute.DisputeReference,
                ReferenceType = "Dispute",
                Metadata = new { dispute.DisputeReference, dispute.BookingReference, dispute.ReasonCategory }
            }, ct);
        }
        catch { }

        return Ok(MapToDto(dispute));
    }

    /// <summary>
    /// Gets customer disputes by customerId, customerName, or bookingReference.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetCustomerDisputes(
        [FromQuery] Guid? customerId,
        [FromQuery] string? customerName,
        [FromQuery] string? bookingReference,
        CancellationToken ct)
    {
        var query = _db.Disputes.AsNoTracking().AsQueryable();

        if (customerId.HasValue && customerId != Guid.Empty)
        {
            query = query.Where(d => d.CustomerId == customerId.Value);
        }
        else if (!string.IsNullOrWhiteSpace(customerName))
        {
            var clean = customerName.Trim().ToLower();
            query = query.Where(d => d.CustomerName.ToLower() == clean || d.CustomerName.ToLower().Contains(clean));
        }

        if (!string.IsNullOrWhiteSpace(bookingReference))
        {
            var altRef = bookingReference.StartsWith("TB-")
                ? bookingReference.Replace("TB-", "PR-")
                : bookingReference.Replace("PR-", "TB-");
            query = query.Where(d => d.BookingReference == bookingReference || d.BookingReference == altRef);
        }

        var list = await query
            .OrderByDescending(d => d.CreatedAt)
            .ToListAsync(ct);

        return Ok(list.Select(MapToDto).ToList());
    }

    /// <summary>
    /// Gets a single dispute by ID or reference.
    /// </summary>
    [HttpGet("{idOrRef}")]
    public async Task<IActionResult> GetDispute(string idOrRef, CancellationToken ct)
    {
        var isGuid = Guid.TryParse(idOrRef, out var id);
        var dispute = await _db.Disputes.AsNoTracking()
            .FirstOrDefaultAsync(d => (isGuid && d.Id == id) || d.DisputeReference.ToLower() == idOrRef.ToLower(), ct);

        if (dispute == null)
            return NotFound(new { error = "Dispute not found." });

        return Ok(MapToDto(dispute));
    }

    /// <summary>
    /// Admin endpoint: lists all disputes with metrics and search filters.
    /// </summary>
    [HttpGet("/api/admin/disputes")]
    public async Task<IActionResult> GetAdminDisputes(
        [FromQuery] string? status,
        [FromQuery] string? search,
        CancellationToken ct)
    {
        var query = _db.Disputes.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && status.ToLower() != "all")
        {
            var cleanStatus = status.Trim().ToLower();
            if (cleanStatus == "pending" || cleanStatus == "open")
            {
                query = query.Where(d => d.Status == "PendingAdminReview" || d.Status == "UnderInvestigation");
            }
            else if (cleanStatus == "resolved")
            {
                query = query.Where(d => d.Status == "Resolved" || d.Status.StartsWith("Resolved_"));
            }
            else
            {
                query = query.Where(d => d.Status.ToLower() == cleanStatus);
            }
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(d =>
                d.DisputeReference.ToLower().Contains(s) ||
                d.BookingReference.ToLower().Contains(s) ||
                d.CustomerName.ToLower().Contains(s) ||
                d.ProviderName.ToLower().Contains(s) ||
                d.ServiceTitle.ToLower().Contains(s) ||
                d.ReasonCategory.ToLower().Contains(s));
        }

        var all = await query.OrderByDescending(d => d.CreatedAt).ToListAsync(ct);

        var total = all.Count;
        var pending = all.Count(d => d.Status == "PendingAdminReview" || d.Status == "UnderInvestigation");
        var resolved = all.Count(d => d.Status == "Resolved" || d.Status.StartsWith("Resolved_"));

        return Ok(new DisputesSummaryResponseDto
        {
            TotalDisputes = total,
            PendingCount = pending,
            ResolvedCount = resolved,
            Disputes = all.Select(MapToDto).ToList()
        });
    }

    /// <summary>
    /// Admin endpoint: resolves the dispute.
    /// Sets dispute to 'Resolved', and updates the underlying Booking to 'Completed' (moves to completed) or 'Cancelled'.
    /// </summary>
    [HttpPost("/api/admin/disputes/{id:guid}/resolve")]
    public async Task<IActionResult> ResolveDispute(Guid id, [FromBody] ResolveDisputeRequest request, CancellationToken ct)
    {
        var dispute = await _db.Disputes.FirstOrDefaultAsync(d => d.Id == id, ct);
        if (dispute == null)
            return NotFound(new { error = "Dispute not found." });

        dispute.Status = "Resolved";
        dispute.ResolutionAction = request.ResolutionAction;
        dispute.ResolutionSummary = request.ResolutionSummary;
        dispute.ResolvedByAdminName = string.IsNullOrWhiteSpace(request.AdminName) ? "Admin Operations" : request.AdminName;
        dispute.ResolvedAt = DateTimeOffset.UtcNow;
        dispute.UpdatedAt = DateTimeOffset.UtcNow;

        var altRef = dispute.BookingReference.StartsWith("TB-")
            ? dispute.BookingReference.Replace("TB-", "PR-")
            : dispute.BookingReference.Replace("PR-", "TB-");

        var booking = await _db.Bookings
            .FirstOrDefaultAsync(b => b.BookingReference == dispute.BookingReference || b.BookingReference == altRef, ct);

        var completion = await _db.JobCompletions
            .FirstOrDefaultAsync(c => c.BookingReference == dispute.BookingReference || c.BookingReference == altRef, ct);

        var isCancelledAction = string.Equals(request.ResolutionAction, "Cancel", StringComparison.OrdinalIgnoreCase) ||
                                string.Equals(request.ResolutionAction, "Cancelled", StringComparison.OrdinalIgnoreCase);

        if (booking != null)
        {
            booking.Status = isCancelledAction ? "Cancelled" : "Completed";
            booking.UpdatedAt = DateTimeOffset.UtcNow;
        }

        if (completion != null)
        {
            completion.Status = isCancelledAction ? "Cancelled" : "CustomerApproved";
            completion.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("Admin resolved Dispute {DisputeRef}. Booking #{BookingRef} status set to {Status}",
            dispute.DisputeReference, dispute.BookingReference, booking?.Status ?? "Completed");

        // Notify Customer of resolution
        try
        {
            await _notificationService.SendNotificationAsync(new CreateNotificationDto
            {
                UserId = dispute.CustomerId,
                UserName = dispute.CustomerName,
                TargetRole = "customer",
                Title = "Dispute Resolved by Admin",
                Message = $"Dispute #{dispute.DisputeReference} has been resolved: {request.ResolutionSummary}. Job marked as {booking?.Status ?? "Completed"}.",
                Type = "DisputeResolved",
                ReferenceId = dispute.BookingReference,
                ReferenceType = "Booking",
                Metadata = new { dispute.DisputeReference, dispute.BookingReference, bookingStatus = booking?.Status }
            }, ct);
        }
        catch { }

        // Notify Provider of resolution
        try
        {
            await _notificationService.SendNotificationAsync(new CreateNotificationDto
            {
                UserId = dispute.ProviderId,
                UserName = dispute.ProviderName,
                TargetRole = "provider",
                Title = "Dispute Resolution Notice",
                Message = $"Admin concluded review of Dispute #{dispute.DisputeReference} for #{dispute.BookingReference}: {request.ResolutionSummary}.",
                Type = "DisputeResolved",
                ReferenceId = dispute.BookingReference,
                ReferenceType = "Booking",
                Metadata = new { dispute.DisputeReference, dispute.BookingReference, bookingStatus = booking?.Status }
            }, ct);
        }
        catch { }

        return Ok(new
        {
            success = true,
            dispute = MapToDto(dispute),
            bookingStatus = booking?.Status ?? "Completed",
            message = $"Dispute resolved successfully. Booking updated to {booking?.Status ?? "Completed"}."
        });
    }

    private static DisputeResponseDto MapToDto(DisputeEntity entity)
    {
        var before = new List<string>();
        if (!string.IsNullOrWhiteSpace(entity.BeforePhotoUrlsJson))
        {
            try { before = JsonSerializer.Deserialize<List<string>>(entity.BeforePhotoUrlsJson) ?? new(); } catch { }
        }

        var after = new List<string>();
        if (!string.IsNullOrWhiteSpace(entity.AfterPhotoUrlsJson))
        {
            try { after = JsonSerializer.Deserialize<List<string>>(entity.AfterPhotoUrlsJson) ?? new(); } catch { }
        }

        var evidence = new List<string>();
        if (!string.IsNullOrWhiteSpace(entity.CustomerEvidencePhotoUrlsJson))
        {
            try { evidence = JsonSerializer.Deserialize<List<string>>(entity.CustomerEvidencePhotoUrlsJson) ?? new(); } catch { }
        }

        return new DisputeResponseDto
        {
            Id = entity.Id,
            DisputeReference = entity.DisputeReference,
            BookingId = entity.BookingId,
            BookingReference = entity.BookingReference,
            CustomerId = entity.CustomerId,
            CustomerName = entity.CustomerName,
            CustomerPhone = entity.CustomerPhone,
            CustomerEmail = entity.CustomerEmail,
            ProviderId = entity.ProviderId,
            ProviderName = entity.ProviderName,
            ServiceTitle = entity.ServiceTitle,
            Category = entity.Category,
            FeeAmount = entity.FeeAmount,
            ReasonCategory = entity.ReasonCategory,
            Description = entity.Description,
            DesiredResolution = entity.DesiredResolution,
            BeforePhotoUrls = before,
            AfterPhotoUrls = after,
            CustomerEvidencePhotoUrls = evidence,
            Status = entity.Status,
            ResolutionSummary = entity.ResolutionSummary,
            ResolutionAction = entity.ResolutionAction,
            ResolvedByAdminName = entity.ResolvedByAdminName,
            ResolvedAt = entity.ResolvedAt,
            CreatedAt = entity.CreatedAt,
            UpdatedAt = entity.UpdatedAt
        };
    }
}
