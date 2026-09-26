using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TaskBridge.Api.Data;

[Table("chat_conversations")]
public class ChatConversation
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public string? BookingReference { get; set; }

    [Required]
    public Guid CustomerId { get; set; }

    [Required]
    [MaxLength(150)]
    public string CustomerName { get; set; } = string.Empty;

    [Required]
    public Guid ProviderId { get; set; }

    [Required]
    [MaxLength(150)]
    public string ProviderName { get; set; } = string.Empty;

    public DateTime LastMessageAt { get; set; } = DateTime.UtcNow;

    public string? LastMessageSnippet { get; set; }

    public int UnreadCustomer { get; set; } = 0;

    public int UnreadProvider { get; set; } = 0;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<ChatMessage> Messages { get; set; } = new List<ChatMessage>();
}

[Table("chat_messages")]
public class ChatMessage
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid ConversationId { get; set; }

    [ForeignKey(nameof(ConversationId))]
    public ChatConversation? Conversation { get; set; }

    [Required]
    public Guid SenderId { get; set; }

    [Required]
    [MaxLength(150)]
    public string SenderName { get; set; } = string.Empty;

    [Required]
    public Guid RecipientId { get; set; }

    [Required]
    [MaxLength(20)]
    public string MessageType { get; set; } = "Text"; // "Text" or "Image"

    /// <summary>
    /// Encrypted using AES-256 before saving to PostgreSQL.
    /// </summary>
    public string EncryptedContent { get; set; } = string.Empty;

    /// <summary>
    /// Direct Cloudflare R2 / S3 URL if MessageType is "Image".
    /// </summary>
    public string? MediaUrl { get; set; }

    public bool IsRead { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

[Table("chat_audit_logs")]
public class ChatAuditLog
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid AdminId { get; set; }

    [Required]
    [MaxLength(150)]
    public string AdminName { get; set; } = string.Empty;

    [Required]
    public Guid ConversationId { get; set; }

    [Required]
    [MaxLength(500)]
    public string Reason { get; set; } = string.Empty;

    public DateTime AccessedAt { get; set; } = DateTime.UtcNow;
}
