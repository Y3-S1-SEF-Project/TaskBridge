namespace TaskBridge.Api.Inquiries;

public sealed class InquiryEntity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string InquiryReference { get; set; } = string.Empty;
    public Guid? UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string? UserEmail { get; set; }
    public string? UserPhone { get; set; }
    public string UserRole { get; set; } = "Customer"; // Customer, Provider
    public string Subject { get; set; } = string.Empty;
    public string Category { get; set; } = "System Issue / Bug";
    public string Message { get; set; } = string.Empty;
    public string? AttachmentUrlsJson { get; set; }
    public string Priority { get; set; } = "Normal"; // Normal, High, Urgent
    public string Status { get; set; } = "Open"; // Open, InProgress, Responded, Resolved
    public string? AdminResponse { get; set; }
    public Guid? RespondedByAdminId { get; set; }
    public string? RespondedByAdminName { get; set; }
    public DateTime? RespondedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
