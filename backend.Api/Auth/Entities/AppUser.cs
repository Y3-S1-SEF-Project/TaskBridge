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
    public string? ProviderCategory { get; set; }
    public string? ProviderSkills { get; set; }
    public string? ProviderServices { get; set; }
    public string? ProviderExperience { get; set; }
    public string? ProviderCertifications { get; set; }
    public string? ProviderServiceAreas { get; set; }
    public string? ProviderAvailability { get; set; }
    public string? ProviderBio { get; set; }
    public decimal? ProviderEarnings { get; set; } = 54000m;
    public decimal? ProviderHourlyRate { get; set; } = 2500m;

    public ProviderProfile? ProviderProfile { get; set; }
}
