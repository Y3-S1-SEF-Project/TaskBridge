using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Auth;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public sealed class AuthController(AuthService auth, AuthDbContext db, IProfileImageService imageService) : ControllerBase
{
    // Registers a new user and sends an email OTP verification code.
    [HttpPost("register")]
    public Task<ChallengeResponse> Register(RegisterRequest request, CancellationToken ct) =>
        auth.Register(request, ct);

    // Verifies the email OTP code and returns an authenticated session.
    [HttpPost("verify-otp")]
    public Task<AuthResponse> VerifyOtp(VerifyOtpRequest request, CancellationToken ct) =>
        auth.VerifyOtp(request, ct);

    // Resends the email OTP code.
    [HttpPost("resend-otp")]
    public Task<ChallengeResponse> ResendOtp(ResendOtpRequest request, CancellationToken ct) =>
        auth.ResendOtp(request, ct);

    // Validates credentials and returns an authenticated session.
    [HttpPost("login")]
    public Task<AuthResponse> Login(LoginRequest request, CancellationToken ct) =>
        auth.Login(request, ct);

    // Returns current authenticated user information.
    [Authorize, HttpGet("me")]
    public async Task<ActionResult<UserResponse>> Me(CancellationToken ct)
    {
        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await db.Users.AsNoTracking().Include(u => u.ProviderProfile).SingleOrDefaultAsync(x => x.Id == id, ct);
        return user is null ? Unauthorized() : Ok(AuthService.MapUser(user, user.ProviderProfile));
    }

    // Updates profile details (Address, Location, Preferences, Photo) from screen C08.
    [Authorize, HttpPost("profile")]
    public async Task<ActionResult<UserResponse>> UpdateProfile(ProfileUpdateRequest request, CancellationToken ct)
    {
        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var updated = await auth.UpdateProfile(id, request, ct);
        return Ok(updated);
    }

    // Uploads a profile photo to Cloudflare R2 and updates the user's ProfilePhotoUrl.
    [HttpPost("profile/photo")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<UserResponse>> UploadProfilePhoto(
        IFormFile file,
        [FromForm] Guid? userId,
        CancellationToken ct)
    {
        var id = await ResolveUserId(userId, ct);
        if (!id.HasValue) return Unauthorized();

        var updated = await auth.UploadProfilePhoto(id.Value, file, ct);
        return Ok(updated);
    }

    // Sets up or updates the user's provider profile and enables Provider Mode.
    [HttpPost("provider/setup")]
    public async Task<ActionResult<UserResponse>> SetupProvider(
        [FromBody] ProviderSetupRequest req,
        [FromQuery] Guid? userId,
        CancellationToken ct)
    {
        var id = await ResolveUserId(userId, ct);
        if (!id.HasValue) return Unauthorized();

        var updated = await auth.UpdateProviderProfile(id.Value, req, ct);
        return Ok(updated);
    }

    // Uploads a certification file (image or document) to Cloudflare R2 and links to provider profile.
    [HttpPost("provider/certification")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<UserResponse>> UploadCertification(
        IFormFile file,
        [FromForm] Guid? userId,
        CancellationToken ct)
    {
        var id = await ResolveUserId(userId, ct);
        if (!id.HasValue) return Unauthorized();

        var updated = await auth.UploadCertification(id.Value, file, ct);
        return Ok(updated);
    }

    // Uploads National ID or Driving License document to Cloudflare R2 for verification (up to 3 photos)
    [HttpPost("provider/verification-document")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<UserResponse>> UploadVerificationDocument(
        IFormFile file,
        [FromForm] string? documentType,
        [FromForm] Guid? userId,
        CancellationToken ct)
    {
        var id = await ResolveUserId(userId, ct);
        if (!id.HasValue) return Unauthorized();

        var user = await db.Users.FindAsync([id.Value], ct);
        if (user is null) return NotFound();

        var provider = await db.Providers.SingleOrDefaultAsync(p => p.UserId == id.Value, ct);

        var existingRaw = provider?.VerificationDocumentUrl ?? user.ProviderVerificationDocumentUrl;
        var existingList = !string.IsNullOrWhiteSpace(existingRaw)
            ? existingRaw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList()
            : new List<string>();

        if (existingList.Count >= 3)
        {
            return BadRequest(new { message = "Maximum of 3 document photos allowed. Please remove a photo before uploading another." });
        }

        var docType = string.IsNullOrWhiteSpace(documentType) ? "National ID" : documentType.Trim();
        var docUrl = await imageService.UploadVerificationDocumentAsync(file, id.Value, docType, ct);

        existingList.Add(docUrl);
        var combinedUrl = string.Join(",", existingList);

        user.ProviderVerificationDocumentUrl = combinedUrl;
        user.ProviderVerificationStatus = "Pending";
        user.UpdatedAt = DateTimeOffset.UtcNow;

        if (provider != null)
        {
            provider.VerificationDocumentUrl = combinedUrl;
            provider.VerificationDocumentType = docType;
            provider.VerificationStatus = "Pending";
            provider.VerificationSubmittedAt = DateTimeOffset.UtcNow;
            provider.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await db.SaveChangesAsync(ct);
        return Ok(AuthService.MapUser(user, provider));
    }

    // Removes an individual verification document photo
    [HttpDelete("provider/verification-document")]
    public async Task<ActionResult<UserResponse>> RemoveVerificationDocument(
        [FromQuery] string? documentUrl,
        [FromQuery] Guid? userId,
        CancellationToken ct)
    {
        var id = await ResolveUserId(userId, ct);
        if (!id.HasValue) return Unauthorized();

        var user = await db.Users.FindAsync([id.Value], ct);
        if (user is null) return NotFound();

        var provider = await db.Providers.SingleOrDefaultAsync(p => p.UserId == id.Value, ct);

        var existingRaw = provider?.VerificationDocumentUrl ?? user.ProviderVerificationDocumentUrl;
        var existingList = !string.IsNullOrWhiteSpace(existingRaw)
            ? existingRaw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList()
            : new List<string>();

        if (!string.IsNullOrWhiteSpace(documentUrl))
        {
            existingList.RemoveAll(u => string.Equals(u.Trim(), documentUrl.Trim(), StringComparison.OrdinalIgnoreCase));
        }

        var combinedUrl = existingList.Count > 0 ? string.Join(",", existingList) : null;
        var newStatus = existingList.Count > 0 ? "Pending" : "Unverified";

        user.ProviderVerificationDocumentUrl = combinedUrl;
        user.ProviderVerificationStatus = newStatus;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        if (provider != null)
        {
            provider.VerificationDocumentUrl = combinedUrl;
            provider.VerificationStatus = newStatus;
            if (existingList.Count == 0)
            {
                provider.VerificationSubmittedAt = null;
            }
            provider.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await db.SaveChangesAsync(ct);
        return Ok(AuthService.MapUser(user, provider));
    }

    private async Task<Guid?> ResolveUserId(Guid? explicitId, CancellationToken ct)
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!string.IsNullOrEmpty(claim) && Guid.TryParse(claim, out var parsed))
            return parsed;

        if (explicitId.HasValue)
            return explicitId.Value;

        var header = Request.Headers.Authorization.ToString();
        if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            var token = header[7..].Trim();
            var u = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.SessionToken == token, ct);
            if (u is not null) return u.Id;
        }

        return null;
    }

    // Revokes the current session token.
    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await auth.Logout(id, ct);
        return NoContent();
    }
}
