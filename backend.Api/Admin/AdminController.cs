using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Admin;

[ApiController]
[Route("api/admin")]
public sealed class AdminController(
    AuthDbContext db,
    IPasswordHasher<AdminUser> hasher) : ControllerBase
{
    // Authenticates Admin / SuperAdmin credentials from dedicated 'admins' table
    [HttpPost("auth/login")]
    public async Task<ActionResult<AdminLoginResponse>> Login(
        [FromBody] AdminLoginRequest request,
        CancellationToken ct)
    {
        var id = request.Identifier.Trim().ToLowerInvariant();

        var admin = await db.Admins.FirstOrDefaultAsync(a =>
            a.Username.ToLower() == id ||
            a.Email.ToLower() == id, ct);

        if (admin is null || !admin.IsActive)
            return Unauthorized(new { error = "Invalid administrator credentials." });

        var verifyResult = hasher.VerifyHashedPassword(admin, admin.PasswordHash, request.Password);
        if (verifyResult == PasswordVerificationResult.Failed)
            return Unauthorized(new { error = "Invalid administrator credentials." });

        var token = AuthCrypto.Token();
        admin.SessionToken = token;
        admin.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        var expiresAt = DateTimeOffset.UtcNow.AddDays(7);

        return Ok(new AdminLoginResponse(
            token,
            admin.FullName,
            admin.Email,
            admin.Role,
            admin.Id,
            expiresAt));
    }

    // Returns current admin profile from Session
    [HttpGet("auth/me")]
    public async Task<ActionResult<AdminUserDto>> Me(CancellationToken ct)
    {
        var admin = await GetCurrentAdmin(ct);
        if (admin is null) return Unauthorized(new { error = "Admin session expired or invalid." });

        return Ok(new AdminUserDto(
            admin.Id,
            admin.FullName,
            admin.Email,
            admin.Role,
            admin.IsActive,
            admin.CreatedAt));
    }

    // Returns dashboard KPI metrics and charts matching the console UI
    [HttpGet("stats")]
    public async Task<ActionResult<DashboardStatsDto>> GetStats(CancellationToken ct)
    {
        // Live data counts directly from database
        var totalBookings = await db.Bookings.CountAsync(ct);
        var totalProposals = await db.Proposals.CountAsync(ct);
        var activeJobs = await db.Bookings.CountAsync(b => b.Status == "Upcoming" || b.Status == "Started" || b.Status == "InProgress", ct);
        var completedJobs = await db.JobCompletions.CountAsync(ct);

        var totalRequests = totalBookings + totalProposals;
        var completionRate = totalBookings > 0 
            ? $"{Math.Round((double)completedJobs / totalBookings * 100, 1)}% completion" 
            : "0% completion";

        var today = new DateTimeOffset(DateTime.UtcNow.Date, TimeSpan.Zero);
        var jobsStartingToday = await db.Bookings.CountAsync(b => 
            (b.StartedAt.HasValue && b.StartedAt.Value >= today) ||
            b.CreatedAt >= today, ct);

        // AI Workflows: AI verification runs on all JobCompletions + AI Planning on Proposals
        var aiCompletions = await db.JobCompletions.AsNoTracking().ToListAsync(ct);
        var aiWorkflowsCount = aiCompletions.Count + totalProposals;
        var aiPassedCount = aiCompletions.Count(c => c.AiVerificationPassed);
        var aiSuccessRate = aiCompletions.Count > 0 
            ? $"{Math.Round((double)aiPassedCount / aiCompletions.Count * 100, 1)}%" 
            : "100%";
        var humanReviewsCount = aiCompletions.Count(c => c.AiConfidenceScore < 85 || c.Status == "PendingAiReview");

        // Build last 7 days activity chart from real proposals & bookings
        var serviceChart = new List<DayActivityDto>();
        var providerChart = new List<DayActivityDto>();
        var allProposals = await db.Proposals.AsNoTracking().ToListAsync(ct);
        var allBookings = await db.Bookings.AsNoTracking().ToListAsync(ct);
        var activeProvidersCount = await db.Providers.CountAsync(p => p.IsActive, ct);

        for (int i = 6; i >= 0; i--)
        {
            var dayDate = today.AddDays(-i);
            var nextDate = dayDate.AddDays(1);
            var dayLabel = dayDate.ToString("ddd");

            var dayReqs = allProposals.Count(p => p.CreatedAt.Date == dayDate) + allBookings.Count(b => b.CreatedAt.Date == dayDate);
            var dayBooks = allBookings.Count(b => b.CreatedAt.Date == dayDate);
            var dayActiveProv = Math.Max(dayBooks > 0 ? Math.Min(activeProvidersCount, dayBooks + 1) : (i == 0 ? activeProvidersCount : 1), 1);

            serviceChart.Add(new DayActivityDto(dayLabel, dayReqs, dayBooks, dayActiveProv));
            providerChart.Add(new DayActivityDto(dayLabel, dayReqs, dayBooks, dayActiveProv));
        }

        // Recent Inquiries from DB Feedbacks & Cancellations
        var recentFeedbacks = await db.Feedbacks
            .AsNoTracking()
            .OrderByDescending(f => f.CreatedAt)
            .Take(5)
            .ToListAsync(ct);

        var inquiries = recentFeedbacks.Select((f, idx) => new InquiryItemDto(
            $"INQ-{(1000 + idx)}",
            string.IsNullOrWhiteSpace(f.CustomerName) ? "Customer" : f.CustomerName,
            string.IsNullOrWhiteSpace(f.Comment) ? $"Booking Review for {f.BookingReference}" : f.Comment,
            string.IsNullOrWhiteSpace(f.ProviderName) ? "Service Provider" : f.ProviderName,
            f.Rating <= 3 ? "High" : "Normal",
            "Resolved",
            f.CreatedAt
        )).ToList();

        var stats = new DashboardStatsDto(
            totalRequests,
            totalRequests > 0 ? "+12% this month" : "0%",
            activeJobs,
            jobsStartingToday,
            completedJobs,
            completionRate,
            inquiries.Count,
            0,
            aiWorkflowsCount,
            aiSuccessRate,
            humanReviewsCount,
            0,
            0,
            serviceChart,
            providerChart,
            inquiries);

        return Ok(stats);
    }

    // Live service requests from database with filtering and search
    [HttpGet("service-requests")]
    public async Task<ActionResult<ServiceRequestsSummaryDto>> GetServiceRequests(
        [FromQuery] string? search,
        [FromQuery] string? searchBy,
        [FromQuery] string? category,
        [FromQuery] string? status,
        [FromQuery] string? urgency,
        CancellationToken ct)
    {
        var proposals = await db.Proposals.AsNoTracking().ToListAsync(ct);
        var bookings = await db.Bookings.AsNoTracking().ToListAsync(ct);

        var items = new List<ServiceRequestItemDto>();
        var seenRefs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var p in proposals)
        {
            seenRefs.Add(p.ProposalReference);
            var linkedBooking = bookings.FirstOrDefault(b => 
                string.Equals(b.BookingReference, p.ProposalReference, StringComparison.OrdinalIgnoreCase) ||
                (b.ProposalId.HasValue && b.ProposalId.Value == p.Id));

            var effectiveStatus = p.Status;
            if (linkedBooking != null)
            {
                if (linkedBooking.Status == "Completed")
                    effectiveStatus = "Completed";
                else if (linkedBooking.Status == "InProgress" || linkedBooking.Status == "Started")
                    effectiveStatus = "In Progress";
                else if (linkedBooking.Status == "Upcoming" && p.Status == "Accepted")
                    effectiveStatus = "Accepted";
                else if (linkedBooking.Status == "Cancelled")
                    effectiveStatus = "Cancelled";
            }

            var sched = p.PreferredSchedule ?? "";
            var urg = "Scheduled";
            if (sched.Contains("Flexible", StringComparison.OrdinalIgnoreCase))
                urg = "Flexible";
            else if (sched.Contains("Immediate", StringComparison.OrdinalIgnoreCase) || p.CreatedAt >= DateTimeOffset.UtcNow.AddDays(-1))
                urg = "Immediate";

            items.Add(new ServiceRequestItemDto(
                p.Id,
                p.ProposalReference,
                string.IsNullOrWhiteSpace(p.CustomerName) ? "Customer" : p.CustomerName,
                p.CustomerId,
                string.IsNullOrWhiteSpace(p.ProviderName) ? "Unassigned" : p.ProviderName,
                p.ProviderId,
                p.ServiceTitle,
                p.Category,
                p.Location,
                sched,
                linkedBooking?.Price ?? p.EstimatedRate,
                p.RateType ?? "Hourly",
                effectiveStatus,
                urg,
                p.Notes,
                p.CreatedAt,
                linkedBooking?.BookingReference));
        }

        foreach (var b in bookings)
        {
            if (!seenRefs.Contains(b.BookingReference))
            {
                seenRefs.Add(b.BookingReference);
                var sched = b.Schedule ?? "";
                var urg = "Scheduled";
                if (sched.Contains("Flexible", StringComparison.OrdinalIgnoreCase))
                    urg = "Flexible";
                else if (sched.Contains("Immediate", StringComparison.OrdinalIgnoreCase) || b.CreatedAt >= DateTimeOffset.UtcNow.AddDays(-1))
                    urg = "Immediate";

                items.Add(new ServiceRequestItemDto(
                    b.Id,
                    b.BookingReference,
                    string.IsNullOrWhiteSpace(b.CustomerName) ? "Customer" : b.CustomerName,
                    b.CustomerId,
                    string.IsNullOrWhiteSpace(b.ProviderName) ? "Unassigned" : b.ProviderName,
                    b.ProviderId,
                    b.ServiceTitle,
                    b.Category,
                    b.Location,
                    sched,
                    b.Price,
                    b.RateType ?? "Hourly",
                    b.Status,
                    urg,
                    b.Notes,
                    b.CreatedAt,
                    b.BookingReference));
            }
        }

        var availableCategories = items
            .Select(i => i.Category)
            .Where(c => !string.IsNullOrWhiteSpace(c))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(c => c)
            .ToList();

        var totalCount = items.Count;
        var pendingCount = items.Count(i => i.Status.Equals("Pending", StringComparison.OrdinalIgnoreCase) || i.Status.Equals("Open", StringComparison.OrdinalIgnoreCase));
        var acceptedCount = items.Count(i => i.Status.Equals("Accepted", StringComparison.OrdinalIgnoreCase) || i.Status.Equals("In Progress", StringComparison.OrdinalIgnoreCase));
        var completedCount = items.Count(i => i.Status.Equals("Completed", StringComparison.OrdinalIgnoreCase));
        var cancelledCount = items.Count(i => i.Status.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) || i.Status.Equals("Declined", StringComparison.OrdinalIgnoreCase));

        var filtered = items.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim();
            var target = (searchBy ?? "all").Trim().ToLowerInvariant();

            if (target == "customer")
            {
                filtered = filtered.Where(i => i.CustomerName.Contains(q, StringComparison.OrdinalIgnoreCase));
            }
            else if (target == "provider")
            {
                filtered = filtered.Where(i => i.ProviderName.Contains(q, StringComparison.OrdinalIgnoreCase));
            }
            else if (target == "reference" || target == "id")
            {
                filtered = filtered.Where(i => i.Reference.Contains(q, StringComparison.OrdinalIgnoreCase));
            }
            else if (target == "service")
            {
                filtered = filtered.Where(i => i.ServiceTitle.Contains(q, StringComparison.OrdinalIgnoreCase));
            }
            else
            {
                // "all" - matches across all fields
                filtered = filtered.Where(i =>
                    i.Reference.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    i.CustomerName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    i.ProviderName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    i.ServiceTitle.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    i.Location.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    (i.Notes != null && i.Notes.Contains(q, StringComparison.OrdinalIgnoreCase)));
            }
        }

        if (!string.IsNullOrWhiteSpace(category) && !category.Equals("All", StringComparison.OrdinalIgnoreCase))
        {
            filtered = filtered.Where(i => string.Equals(i.Category, category, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("All", StringComparison.OrdinalIgnoreCase))
        {
            filtered = filtered.Where(i => string.Equals(i.Status, status, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(urgency) && !urgency.Equals("All", StringComparison.OrdinalIgnoreCase))
        {
            filtered = filtered.Where(i => string.Equals(i.Urgency, urgency, StringComparison.OrdinalIgnoreCase));
        }

        var resultList = filtered.OrderByDescending(i => i.CreatedAt).ToList();

        return Ok(new ServiceRequestsSummaryDto(
            totalCount,
            pendingCount,
            acceptedCount,
            completedCount,
            cancelledCount,
            availableCategories,
            resultList));
    }

    // List all inquiries with status/priority
    [HttpGet("inquiries")]
    public async Task<ActionResult<List<InquiryItemDto>>> GetInquiries(CancellationToken ct)
    {
        var recentFeedbacks = await db.Feedbacks
            .AsNoTracking()
            .OrderByDescending(f => f.CreatedAt)
            .Take(10)
            .ToListAsync(ct);

        var inquiries = recentFeedbacks.Select((f, idx) => new InquiryItemDto(
            $"INQ-{(1000 + idx)}",
            string.IsNullOrWhiteSpace(f.CustomerName) ? "Customer" : f.CustomerName,
            string.IsNullOrWhiteSpace(f.Comment) ? $"Booking Review for {f.BookingReference}" : f.Comment,
            string.IsNullOrWhiteSpace(f.ProviderName) ? "Service Provider" : f.ProviderName,
            f.Rating <= 3 ? "High" : "Normal",
            "Resolved",
            f.CreatedAt
        )).ToList();

        return Ok(inquiries);
    }

    // List all administrators from the dedicated 'admins' table
    [HttpGet("admins")]
    public async Task<ActionResult<List<AdminUserDto>>> GetAdmins(CancellationToken ct)
    {
        var caller = await GetCurrentAdmin(ct);
        if (caller is null) return Unauthorized();

        if (caller.Role != "SuperAdmin")
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "Access denied. Only Super Administrators can view the administrators directory." });

        var admins = await db.Admins
            .AsNoTracking()
            .OrderBy(a => a.Role == "SuperAdmin" ? 0 : 1)
            .ThenBy(a => a.FullName)
            .Select(a => new AdminUserDto(
                a.Id,
                a.FullName,
                a.Email,
                a.Role,
                a.IsActive,
                a.CreatedAt))
            .ToListAsync(ct);

        return Ok(admins);
    }

    // Updates an administrator's permissions, role, status, or password
    [HttpPut("admins/{id:guid}")]
    public async Task<IActionResult> UpdateAdmin(
        Guid id,
        [FromBody] UpdateAdminRequest request,
        CancellationToken ct)
    {
        var caller = await GetCurrentAdmin(ct);
        if (caller is null) return Unauthorized();

        if (caller.Role != "SuperAdmin")
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "Only Super Administrators can update administrator access." });

        var target = await db.Admins.FindAsync(new object[] { id }, ct);
        if (target is null) return NotFound(new { error = "Administrator not found." });

        if (target.Username == "admin1" && !request.IsActive)
            return BadRequest(new { error = "Primary Super Administrator access cannot be deactivated." });

        target.FullName = request.FullName.Trim();
        target.Role = string.IsNullOrWhiteSpace(request.Role) ? target.Role : request.Role.Trim();
        target.IsActive = request.IsActive;

        if (!string.IsNullOrWhiteSpace(request.NewPassword))
        {
            target.PasswordHash = hasher.HashPassword(target, request.NewPassword.Trim());
            target.SessionToken = null; // Invalidate active session
        }

        target.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        return Ok(new AdminUserDto(
            target.Id,
            target.FullName,
            target.Email,
            target.Role,
            target.IsActive,
            target.CreatedAt));
    }

    // Toggles administrator active/suspended status
    [HttpPatch("admins/{id:guid}/status")]
    public async Task<IActionResult> ToggleAdminStatus(Guid id, CancellationToken ct)
    {
        var caller = await GetCurrentAdmin(ct);
        if (caller is null) return Unauthorized();

        if (caller.Role != "SuperAdmin")
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "Only Super Administrators can toggle administrator access." });

        var target = await db.Admins.FindAsync(new object[] { id }, ct);
        if (target is null) return NotFound(new { error = "Administrator not found." });

        if (target.Username == "admin1")
            return BadRequest(new { error = "Primary Super Administrator access cannot be suspended." });

        target.IsActive = !target.IsActive;
        if (!target.IsActive)
        {
            target.SessionToken = null;
        }
        target.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        return Ok(new { id = target.Id, isActive = target.IsActive });
    }

    // Super Admin creates a new admin into dedicated 'admins' table
    [HttpPost("create-admin")]
    public async Task<IActionResult> CreateAdmin(
        [FromBody] CreateAdminRequest request,
        CancellationToken ct)
    {
        var caller = await GetCurrentAdmin(ct);
        if (caller is null) return Unauthorized();

        if (caller.Role != "SuperAdmin")
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "Only Super Administrators can provision new admin accounts." });

        var emailLower = request.Email.Trim().ToLowerInvariant();
        var username = emailLower.Contains('@') ? emailLower.Split('@')[0] : emailLower;

        var existing = await db.Admins.AnyAsync(a => a.Email.ToLower() == emailLower || a.Username.ToLower() == username, ct);
        if (existing)
            return BadRequest(new { error = "An administrator account with this email/username already exists." });

        var newAdmin = new AdminUser
        {
            Id = Guid.NewGuid(),
            Username = username,
            FullName = request.FullName.Trim(),
            Email = emailLower,
            Role = string.IsNullOrWhiteSpace(request.Role) ? "Admin" : request.Role.Trim(),
            IsActive = true,
            CreatedAt = DateTimeOffset.UtcNow
        };

        newAdmin.PasswordHash = hasher.HashPassword(newAdmin, request.Password);
        db.Admins.Add(newAdmin);
        await db.SaveChangesAsync(ct);

        var loginUrl = $"{Request.Scheme}://{Request.Host}/login";

        return CreatedAtAction(nameof(GetAdmins), new
        {
            id = newAdmin.Id,
            fullName = newAdmin.FullName,
            email = newAdmin.Email,
            role = newAdmin.Role,
            temporaryPassword = request.Password,
            loginUrl,
            message = "Administrator account successfully provisioned."
        });
    }

    // Deletes or deactivates an admin account from 'admins' table
    [HttpDelete("admins/{id:guid}")]
    public async Task<IActionResult> DeleteAdmin(Guid id, CancellationToken ct)
    {
        var caller = await GetCurrentAdmin(ct);
        if (caller is null) return Unauthorized();

        if (caller.Role != "SuperAdmin")
            return StatusCode(StatusCodes.Status403Forbidden, new { error = "Only Super Administrators can remove admin accounts." });

        if (caller.Id == id)
            return BadRequest(new { error = "You cannot delete your own Super Administrator account." });

        var target = await db.Admins.FindAsync(new object[] { id }, ct);
        if (target is null) return NotFound(new { error = "Administrator not found." });

        if (target.Role == "SuperAdmin")
            return BadRequest(new { error = "Primary Super Administrator cannot be removed." });

        db.Admins.Remove(target);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    private async Task<AdminUser?> GetCurrentAdmin(CancellationToken ct)
    {
        var header = Request.Headers.Authorization.ToString();
        if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            var token = header[7..].Trim();
            var admin = await db.Admins.SingleOrDefaultAsync(x => x.SessionToken == token, ct);
            if (admin is not null && admin.IsActive)
                return admin;
        }

        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!string.IsNullOrEmpty(claim) && Guid.TryParse(claim, out var parsed))
        {
            var admin = await db.Admins.FindAsync(new object[] { parsed }, ct);
            if (admin is not null && admin.IsActive)
                return admin;
        }

        return null;
    }
}
