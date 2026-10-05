using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TaskBridge.Api.Disputes;

[Table("disputes")]
public sealed class DisputeEntity
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [MaxLength(50)]
    public string DisputeReference { get; set; } = string.Empty; // e.g. DSP-4821

    public Guid? BookingId { get; set; }

    [MaxLength(50)]
    public string BookingReference { get; set; } = string.Empty; // e.g. PR-5878

    public Guid? CustomerId { get; set; }

    [MaxLength(150)]
    public string CustomerName { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? CustomerPhone { get; set; }

    [MaxLength(255)]
    public string? CustomerEmail { get; set; }

    public Guid? ProviderId { get; set; }

    [MaxLength(150)]
    public string ProviderName { get; set; } = string.Empty;

    [MaxLength(200)]
    public string ServiceTitle { get; set; } = string.Empty;

    [MaxLength(100)]
    public string Category { get; set; } = string.Empty;

    public decimal FeeAmount { get; set; }

    [MaxLength(100)]
    public string ReasonCategory { get; set; } = string.Empty; // e.g. Work Incomplete, Poor Quality, Damage, Billing Dispute, Other

    public string Description { get; set; } = string.Empty; // Customer issue explanation

    [MaxLength(100)]
    public string DesiredResolution { get; set; } = string.Empty; // e.g. Refund Full Amount, Free Revision / Rework, Partial Discount, Cancel Booking

    public string? BeforePhotoUrlsJson { get; set; } // JSON array of job before photos
    public string? AfterPhotoUrlsJson { get; set; } // JSON array of job after photos
    public string? CustomerEvidencePhotoUrlsJson { get; set; } // JSON array of customer proof photos

    [MaxLength(50)]
    public string Status { get; set; } = "PendingAdminReview"; // PendingAdminReview, UnderInvestigation, Resolved, Cancelled

    public string? ResolutionSummary { get; set; } // Admin notes / decision rationale

    [MaxLength(50)]
    public string? ResolutionAction { get; set; } // Completed, Cancelled, Refunded

    public Guid? ResolvedByAdminId { get; set; }

    [MaxLength(150)]
    public string? ResolvedByAdminName { get; set; }

    public DateTimeOffset? ResolvedAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
}
