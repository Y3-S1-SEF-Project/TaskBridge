namespace TaskBridge.Api.Auth;

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
    public double Rating { get; set; } = 0.0;
    public int ReviewCount { get; set; } = 0;
    public bool IsActive { get; set; } = true;
    public string? Bio { get; set; }

    // Verification & KYC Document Fields
    public bool IsVerified { get; set; } = false;
    public string? VerificationDocumentUrl { get; set; }
    public string? VerificationDocumentType { get; set; } // "National ID" or "Driving License"
    public string VerificationStatus { get; set; } = "Unverified"; // "Unverified", "Pending", "Approved", "Rejected"
    public DateTimeOffset? VerificationSubmittedAt { get; set; }
    public DateTimeOffset? VerificationApprovedAt { get; set; }
    public string? VerificationNotes { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}
