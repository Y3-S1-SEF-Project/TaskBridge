using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed class AppUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string FullName { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string? Address { get; set; }
    public string? Location { get; set; }
    public string? Preferences { get; set; }
    public string? ProfilePhotoUrl { get; set; }
    public string? EmailOtp { get; set; }
    public DateTimeOffset? EmailOtpExpiresAt { get; set; }
    public bool IsEmailVerified { get; set; }
    public string? SessionToken { get; set; }
    public int FailedLogins { get; set; }
    public DateTimeOffset? LockedUntil { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }

    // Provider mode profile details
    public bool IsProvider { get; set; }
    public string? ProviderSkills { get; set; }
    public string? ProviderServices { get; set; }
    public string? ProviderExperience { get; set; }
    public string? ProviderCertifications { get; set; }
    public string? ProviderServiceAreas { get; set; }
    public string? ProviderAvailability { get; set; }
    public string? ProviderBio { get; set; }
    public decimal? ProviderEarnings { get; set; } = 54000m;

    public ProviderProfile? ProviderProfile { get; set; }
}

public sealed class ProviderProfile
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = null!;

    public string Category { get; set; } = "General";
    public string? Skills { get; set; }
    public string? Services { get; set; }
    public string? Experience { get; set; }
    public string? Certifications { get; set; }
    public string? ServiceAreas { get; set; }
    public string? Availability { get; set; }
    public decimal HourlyRate { get; set; } = 2500m;
    public double Rating { get; set; } = 4.8;
    public int ReviewCount { get; set; } = 12;
    public bool IsActive { get; set; } = true;
    public string? Bio { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}

public sealed record RegisterRequest(
    [Required, StringLength(100, MinimumLength = 2)] string FullName,
    [Required, EmailAddress, StringLength(255)] string Email,
    [Required, StringLength(24)] string Phone,
    [Required, StringLength(128, MinimumLength = 8)] string Password);

public sealed record LoginRequest(
    [Required, StringLength(255)] string Identifier,
    [Required, StringLength(128)] string Password);

public sealed record VerifyOtpRequest(
    [Required, EmailAddress] string Email,
    [Required, RegularExpression(@"^\d{6}$")] string Code);

public sealed record ResendOtpRequest(
    [Required, EmailAddress] string Email);

public sealed record ForgotPasswordRequest(
    [Required, EmailAddress] string Email);

public sealed record ResetPasswordRequest(
    [Required, EmailAddress] string Email,
    [Required, RegularExpression(@"^\d{6}$")] string Code,
    [Required, StringLength(128, MinimumLength = 8)] string NewPassword);

public sealed record ProfileUpdateRequest(
    string? FullName,
    string? Address,
    string? Location,
    string? Preferences,
    string? ProfilePhotoUrl);

public sealed record ProviderSetupRequest(
    string? Skills,
    string? Services,
    string? Experience,
    string? Certifications,
    string? ServiceAreas,
    string? Availability,
    string? Bio,
    string? Location = null);

public sealed record ChallengeResponse(
    string Email,
    DateTimeOffset ExpiresAt,
    string Message);

public sealed record UserResponse(
    Guid Id,
    string FullName,
    string Email,
    string Phone,
    string? Address,
    string? Location,
    string? Preferences,
    string? ProfilePhotoUrl,
    bool IsProvider = false,
    string? ProviderSkills = null,
    string? ProviderServices = null,
    string? ProviderExperience = null,
    string? ProviderCertifications = null,
    string? ProviderServiceAreas = null,
    string? ProviderAvailability = null,
    string? ProviderBio = null,
    decimal? ProviderEarnings = null);

public sealed record AuthResponse(
    string AccessToken,
    DateTimeOffset ExpiresAt,
    UserResponse User,
    bool IsNewUser);

public sealed class AuthProblem(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
