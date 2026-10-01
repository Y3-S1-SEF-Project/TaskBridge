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

        var stats = new DashboardStatsDto(
            totalRequests,
            totalRequests > 0 ? "+0% this month" : "0%",
            activeJobs,
            0,
            completedJobs,
            completionRate,
            0,
            0,
            0,
            "0%",
            0,
            0,
            0,
            new List<DayActivityDto>(),
            new List<DayActivityDto>(),
            new List<InquiryItemDto>());

        return Ok(stats);
    }

    // List all inquiries with status/priority
    [HttpGet("inquiries")]
    public ActionResult<List<InquiryItemDto>> GetInquiries()
    {
        return Ok(new List<InquiryItemDto>());
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
