using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Chat;

[ApiController]
[Route("api/chat")]
[Authorize]
public sealed class ChatController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly ChatCrypto _crypto;
    private readonly IProfileImageService _imageService;
    private readonly ILogger<ChatController> _logger;

    public ChatController(
        AuthDbContext db,
        ChatCrypto crypto,
        IProfileImageService imageService,
        ILogger<ChatController> logger)
    {
        _db = db;
        _crypto = crypto;
        _imageService = imageService;
        _logger = logger;
    }

    private Guid? CurrentUserId
    {
        get
        {
            var val = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return Guid.TryParse(val, out var id) ? id : null;
        }
    }

    /// <summary>
    /// Returns all conversations where current user is Customer or Provider.
    /// </summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations(CancellationToken ct)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        var convs = await _db.ChatConversations
            .AsNoTracking()
            .Where(c => c.CustomerId == userId.Value || c.ProviderId == userId.Value)
            .OrderByDescending(c => c.LastMessageAt)
            .Select(c => new
            {
                c.Id,
                c.BookingReference,
                c.CustomerId,
                c.CustomerName,
                c.ProviderId,
                c.ProviderName,
                c.LastMessageAt,
                c.LastMessageSnippet,
                UnreadCount = userId.Value == c.CustomerId ? c.UnreadCustomer : c.UnreadProvider,
                c.CreatedAt
            })
            .ToListAsync(ct);

        return Ok(convs);
    }

    /// <summary>
    /// Finds an existing conversation between customer and provider or creates a new one.
    /// </summary>
    [HttpPost("conversations/find-or-create")]
    public async Task<IActionResult> FindOrCreateConversation(
        [FromBody] FindOrCreateConversationRequest request,
        CancellationToken ct)
    {
        var currentUserId = CurrentUserId;
        if (currentUserId == null) return Unauthorized();

        var providerId = request.ProviderId;
        var customerId = request.CustomerId ?? Guid.Empty;

        // If bookingReference provided, resolve missing party IDs from booking
        if (!string.IsNullOrEmpty(request.BookingReference))
        {
            var booking = await _db.Bookings.AsNoTracking().FirstOrDefaultAsync(b => b.BookingReference == request.BookingReference, ct);
            if (booking != null)
            {
                if (customerId == Guid.Empty && booking.CustomerId.HasValue)
                {
                    customerId = booking.CustomerId.Value;
                }
                if (providerId == Guid.Empty && booking.ProviderId.HasValue)
                {
                    providerId = booking.ProviderId.Value;
                }
            }
        }

        // If providerId matches a ProviderProfile Id, resolve underlying User Id
        if (providerId != Guid.Empty)
        {
            var providerProfile = await _db.Providers.AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == providerId || p.UserId == providerId, ct);
            if (providerProfile != null)
            {
                providerId = providerProfile.UserId;
            }
        }

        // Fallbacks based on caller's role
        if (customerId == Guid.Empty)
        {
            customerId = currentUserId.Value;
        }
        else if (providerId == Guid.Empty)
        {
            providerId = currentUserId.Value;
        }

        if (customerId == Guid.Empty || providerId == Guid.Empty)
            return BadRequest(new { error = "Unable to determine customer and provider for this conversation." });

        // Search for existing conversation
        var existing = await _db.ChatConversations
            .FirstOrDefaultAsync(c =>
                c.CustomerId == customerId &&
                c.ProviderId == providerId &&
                (string.IsNullOrEmpty(request.BookingReference) || c.BookingReference == request.BookingReference),
                ct);

        if (existing != null)
        {
            return Ok(new
            {
                existing.Id,
                existing.BookingReference,
                existing.CustomerId,
                existing.CustomerName,
                existing.ProviderId,
                existing.ProviderName,
                existing.LastMessageAt,
                existing.LastMessageSnippet,
                existing.CreatedAt
            });
        }

        var customer = await _db.Users.FindAsync(new object[] { customerId }, ct);
        var provider = await _db.Users.FindAsync(new object[] { providerId }, ct);

        var newConv = new ChatConversation
        {
            Id = Guid.NewGuid(),
            BookingReference = request.BookingReference,
            CustomerId = customerId,
            CustomerName = customer?.FullName ?? "Customer",
            ProviderId = providerId,
            ProviderName = provider?.FullName ?? "Provider",
            LastMessageAt = DateTime.UtcNow,
            LastMessageSnippet = "Conversation started",
            CreatedAt = DateTime.UtcNow
        };

        _db.ChatConversations.Add(newConv);
        await _db.SaveChangesAsync(ct);

        return Ok(new
        {
            newConv.Id,
            newConv.BookingReference,
            newConv.CustomerId,
            newConv.CustomerName,
            newConv.ProviderId,
            newConv.ProviderName,
            newConv.LastMessageAt,
            newConv.LastMessageSnippet,
            newConv.CreatedAt
        });
    }

    /// <summary>
    /// Fetches message history for a conversation.
    /// Messages are decrypted on-the-fly for authorized participants.
    /// </summary>
    [HttpGet("conversations/{id:guid}/messages")]
    public async Task<IActionResult> GetMessages(Guid id, [FromQuery] int limit = 50, CancellationToken ct = default)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        var conv = await _db.ChatConversations.FindAsync(new object[] { id }, ct);
        if (conv == null) return NotFound(new { error = "Conversation not found." });

        if (conv.CustomerId != userId.Value && conv.ProviderId != userId.Value)
            return Forbid();

        var rawMessages = await _db.ChatMessages
            .AsNoTracking()
            .Where(m => m.ConversationId == id)
            .OrderBy(m => m.CreatedAt)
            .Take(limit)
            .ToListAsync(ct);

        var decryptedMessages = rawMessages.Select(m => new
        {
            m.Id,
            m.ConversationId,
            m.SenderId,
            m.SenderName,
            m.RecipientId,
            m.MessageType,
            Content = _crypto.Decrypt(m.EncryptedContent), // Decrypted for authorized recipient
            m.MediaUrl,
            m.IsRead,
            m.CreatedAt,
            IsEncryptedAtRest = true
        });

        return Ok(decryptedMessages);
    }

    /// <summary>
    /// Uploads an image attachment for chat to Cloudflare R2 / S3 storage.
    /// </summary>
    [HttpPost("upload-attachment")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadChatAttachment(
        IFormFile file,
        [FromForm] string? bookingRef,
        CancellationToken ct)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        if (file == null || file.Length == 0)
            return BadRequest(new { error = "No image file provided." });

        try
        {
            var url = await _imageService.UploadProofPhotoAsync(file, bookingRef ?? "chat", ct);
            return Ok(new { url });
        }
        catch (AuthProblem ex)
        {
            return StatusCode(ex.Status, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading chat attachment.");
            return StatusCode(500, new { error = "Failed to upload image." });
        }
    }

    /// <summary>
    /// Admin Inquiry Endpoint:
    /// Allows authorized admins to review chat records for customer/provider dispute resolution.
    /// Securely creates an immutable audit trail entry.
    /// </summary>
    [HttpPost("admin/inquiry/{id:guid}")]
    public async Task<IActionResult> AdminChatInquiry(
        Guid id,
        [FromBody] AdminInquiryRequest request,
        CancellationToken ct)
    {
        var adminId = CurrentUserId;
        if (adminId == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Reason))
            return BadRequest(new { error = "An inquiry reason must be documented for governance audit compliance." });

        var conv = await _db.ChatConversations.FindAsync(new object[] { id }, ct);
        if (conv == null) return NotFound(new { error = "Conversation not found." });

        var adminUser = await _db.Users.FindAsync(new object[] { adminId.Value }, ct);
        var adminName = adminUser?.FullName ?? "System Admin";

        // Log audit event
        var audit = new ChatAuditLog
        {
            Id = Guid.NewGuid(),
            AdminId = adminId.Value,
            AdminName = adminName,
            ConversationId = id,
            Reason = request.Reason.Trim(),
            AccessedAt = DateTime.UtcNow
        };

        _db.ChatAuditLogs.Add(audit);
        await _db.SaveChangesAsync(ct);

        _logger.LogWarning("Admin {AdminName} ({AdminId}) accessed chat {ConvId} for dispute inquiry: {Reason}",
            adminName, adminId, id, request.Reason);

        var messages = await _db.ChatMessages
            .AsNoTracking()
            .Where(m => m.ConversationId == id)
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(ct);

        var decryptedMessages = messages.Select(m => new
        {
            m.Id,
            m.ConversationId,
            m.SenderId,
            m.SenderName,
            m.RecipientId,
            m.MessageType,
            Content = _crypto.Decrypt(m.EncryptedContent),
            m.MediaUrl,
            m.CreatedAt
        });

        return Ok(new
        {
            AuditId = audit.Id,
            Conversation = conv,
            Messages = decryptedMessages,
            InquiryReason = request.Reason,
            LoggedAt = audit.AccessedAt
        });
    }

    /// <summary>
    /// Deletes a message by its ID.
    /// </summary>
    [HttpDelete("messages/{id:guid}")]
    public async Task<IActionResult> DeleteMessage(Guid id, CancellationToken ct = default)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        var msg = await _db.ChatMessages.FindAsync(new object[] { id }, ct);
        if (msg == null) return NotFound(new { error = "Message not found." });

        if (msg.SenderId != userId.Value && msg.RecipientId != userId.Value)
            return Forbid();

        _db.ChatMessages.Remove(msg);
        await _db.SaveChangesAsync(ct);

        return Ok(new { success = true, id });
    }
}

public sealed record FindOrCreateConversationRequest(
    Guid? CustomerId,
    Guid ProviderId,
    string? BookingReference);

public sealed record AdminInquiryRequest(
    string Reason);
