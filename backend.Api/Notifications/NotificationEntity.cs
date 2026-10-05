using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TaskBridge.Api.Notifications;

[Table("notifications")]
public sealed class NotificationEntity
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid? UserId { get; set; }

    [MaxLength(150)]
    public string? UserName { get; set; }

    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? TargetRole { get; set; } // customer, provider, or null for both

    [MaxLength(50)]
    public string Type { get; set; } = "General"; 
    // Types: ProposalReceived, ProposalAccepted, ProposalDeclined, CounterBid, JobStarted, JobCompleted, BookingCancelled, ServiceRequestCreated, PaymentReceived, System

    [MaxLength(100)]
    public string? ReferenceId { get; set; }

    [MaxLength(50)]
    public string? ReferenceType { get; set; } // Proposal, Booking, ServiceRequest

    public string? MetadataJson { get; set; }

    public bool IsRead { get; set; } = false;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
