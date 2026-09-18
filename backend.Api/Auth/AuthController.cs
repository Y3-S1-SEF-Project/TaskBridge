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
public sealed class AuthController(AuthService auth, AuthDbContext db) : ControllerBase
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
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        return user is null ? Unauthorized() : Ok(AuthService.MapUser(user));
    }

    // Updates profile details (Address, Location, Preferences, Photo) from screen C08.
    [Authorize, HttpPost("profile")]
    public async Task<ActionResult<UserResponse>> UpdateProfile(ProfileUpdateRequest request, CancellationToken ct)
    {
        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var updated = await auth.UpdateProfile(id, request, ct);
        return Ok(updated);
    }

    // Uploads a profile photo to Cloudinary and updates the user's ProfilePhotoUrl.
    [HttpPost("profile/photo")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<UserResponse>> UploadProfilePhoto(
        IFormFile file,
        [FromForm] Guid? userId,
        CancellationToken ct)
    {
        Guid id;
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!string.IsNullOrEmpty(claim) && Guid.TryParse(claim, out var parsed))
        {
            id = parsed;
        }
        else if (userId.HasValue)
        {
            id = userId.Value;
        }
        else
        {
            var header = Request.Headers.Authorization.ToString();
            if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                var token = header[7..].Trim();
                var u = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.SessionToken == token, ct);
                if (u is not null) id = u.Id;
                else return Unauthorized();
            }
            else
            {
                return Unauthorized();
            }
        }

        var updated = await auth.UploadProfilePhoto(id, file, ct);
        return Ok(updated);
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
