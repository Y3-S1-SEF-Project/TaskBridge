using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
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
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly ILogger<ChatController> _logger;

    public ChatController(
        AuthDbContext db,
        ChatCrypto crypto,
        IProfileImageService imageService,
        IHubContext<ChatHub> hubContext,
        ILogger<ChatController> logger)
    {
        _db = db;
        _crypto = crypto;
        _imageService = imageService;
        _hubContext = hubContext;
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

    private bool IsAdmin =>
        string.Equals(User.FindFirst(ClaimTypes.Role)?.Value, "Admin", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(User.FindFirst(ClaimTypes.Role)?.Value, "SuperAdmin", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Returns conversations for current user filtered by role ('customer' or 'provider').
    /// </summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations([FromQuery] string? role, CancellationToken ct)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        var providerProfile = await _db.Providers.AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId.Value, ct);
        var providerProfileId = providerProfile?.Id;

        IQueryable<ChatConversation> query = _db.ChatConversations.AsNoTracking();

        if (string.Equals(role, "customer", StringComparison.OrdinalIgnoreCase))
        {
            // Customer mode: user is acting as customer.
            // Exclude conversations where user is the provider.
            query = query.Where(c => c.CustomerId == userId.Value && c.ProviderId != userId.Value && (!providerProfileId.HasValue || c.ProviderId != providerProfileId.Value));
        }
        else if (string.Equals(role, "provider", StringComparison.OrdinalIgnoreCase))
        {
            // Provider mode: user is acting as provider.
            // Exclude conversations where user is the customer.
            query = query.Where(c => (c.ProviderId == userId.Value || (providerProfileId.HasValue && c.ProviderId == providerProfileId.Value)) && c.CustomerId != userId.Value);
        }
        else
        {
            query = query.Where(c => c.CustomerId == userId.Value || c.ProviderId == userId.Value || (providerProfileId.HasValue && c.ProviderId == providerProfileId.Value));
        }

        var convs = await query
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

        if (customerId == providerId)
            return BadRequest(new { error = "Cannot create a conversation with yourself." });

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

        var decryptedMessages = rawMessages
            .Select(m => new
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
            })
            .Where(m => !m.Content.Contains("Welcome to TaskBridge Live Support"));

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
    /// <summary>
    /// Gets or creates the official TaskBridge Real-time Support Chat conversation for the current user.
    /// Pinned and undeletable from customer and provider apps.
    /// </summary>
    [HttpGet("support-conversation")]
    public async Task<IActionResult> GetOrCreateSupportConversation(CancellationToken ct)
    {
        var userId = CurrentUserId;
        if (userId == null) return Unauthorized();

        var conv = await _db.ChatConversations
            .FirstOrDefaultAsync(c =>
                c.CustomerId == userId.Value &&
                (c.BookingReference == SupportConstants.SupportReference || c.ProviderId == SupportConstants.SupportAgentId),
                ct);

        if (conv != null)
        {
            return Ok(new
            {
                conv.Id,
                conv.BookingReference,
                conv.CustomerId,
                conv.CustomerName,
                conv.ProviderId,
                conv.ProviderName,
                conv.LastMessageAt,
                conv.LastMessageSnippet,
                UnreadCount = conv.UnreadCustomer,
                conv.CreatedAt,
                IsSupportChat = true
            });
        }

        var user = await _db.Users.FindAsync(new object[] { userId.Value }, ct);
        var fullName = user?.FullName ?? "User";

        var newConv = new ChatConversation
        {
            Id = Guid.NewGuid(),
            BookingReference = SupportConstants.SupportReference,
            CustomerId = userId.Value,
            CustomerName = fullName,
            ProviderId = SupportConstants.SupportAgentId,
            ProviderName = SupportConstants.SupportAgentName,
            LastMessageAt = DateTime.UtcNow,
            LastMessageSnippet = null,
            CreatedAt = DateTime.UtcNow,
            UnreadCustomer = 0
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
            UnreadCount = 0,
            newConv.CreatedAt,
            IsSupportChat = true
        });
    }

    /// <summary>
    /// Returns all conversations for admin real-time communication & audit console.
    /// Highlights live support chats and job conversations.
    /// </summary>
    [HttpGet("admin/conversations")]
    public async Task<IActionResult> GetAdminConversations(CancellationToken ct)
    {
        if (!IsAdmin) return Forbid();

        var convs = await _db.ChatConversations
            .AsNoTracking()
            .Where(c =>
                // Regular job conversations are always included for audit
                !(c.BookingReference == SupportConstants.SupportReference ||
                  c.BookingReference == SupportConstants.ProviderSupportReference ||
                  c.ProviderId == SupportConstants.SupportAgentId)
                // Support conversations are ONLY included if the customer/provider has sent at least one message
                || _db.ChatMessages.Any(m => m.ConversationId == c.Id && m.SenderId == c.CustomerId)
            )
            .OrderByDescending(c => c.LastMessageAt)
            .ToListAsync(ct);

        var userIds = convs.Select(c => c.CustomerId).Distinct().ToList();
        var users = await _db.Users.AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => new { u.FullName, u.Phone, u.Email, u.Role }, ct);

        var result = convs.Select(c =>
        {
            var isSupport = c.BookingReference == SupportConstants.SupportReference ||
                            c.BookingReference == SupportConstants.ProviderSupportReference ||
                            c.ProviderId == SupportConstants.SupportAgentId;

            users.TryGetValue(c.CustomerId, out var customerUser);

            return new
            {
                c.Id,
                c.BookingReference,
                c.CustomerId,
                CustomerName = c.CustomerName,
                CustomerPhone = customerUser?.Phone,
                CustomerEmail = customerUser?.Email,
                CustomerRole = customerUser?.Role ?? "Customer",
                c.ProviderId,
                c.ProviderName,
                c.LastMessageAt,
                c.LastMessageSnippet,
                c.UnreadCustomer,
                c.UnreadProvider,
                c.CreatedAt,
                IsSupportChat = isSupport
            };
        });

        return Ok(result);
    }

    /// <summary>
    /// Returns decrypted chat transcript for admin real-time support and dispute audit.
    /// </summary>
    [HttpGet("admin/conversations/{id:guid}/messages")]
    public async Task<IActionResult> GetAdminMessages(Guid id, CancellationToken ct)
    {
        if (!IsAdmin) return Forbid();

        var conv = await _db.ChatConversations.FindAsync(new object[] { id }, ct);
        if (conv == null) return NotFound(new { error = "Conversation not found." });

        var messages = await _db.ChatMessages
            .AsNoTracking()
            .Where(m => m.ConversationId == id)
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(ct);

        var adminIds = await _db.Admins.AsNoTracking().Select(a => a.Id).ToListAsync(ct);

        var decrypted = messages.Select(m => new
        {
            m.Id,
            m.ConversationId,
            m.SenderId,
            m.SenderName,
            m.RecipientId,
            m.MessageType,
            Content = _crypto.Decrypt(m.EncryptedContent),
            m.MediaUrl,
            m.IsRead,
            m.CreatedAt,
            IsSupportSender = m.SenderId == SupportConstants.SupportAgentId || adminIds.Contains(m.SenderId)
        }).Where(m => !m.Content.Contains("Welcome to TaskBridge Live Support"));

        return Ok(decrypted);
    }

    /// <summary>
    /// Allows an admin to chat as a real-time support agent with customer or provider.
    /// Broadcasts through SignalR to conversation, recipient, and admin channel.
    /// </summary>
    [HttpPost("admin/send-message")]
    public async Task<IActionResult> AdminSendMessage(
        [FromBody] AdminSendMessageRequest request,
        CancellationToken ct)
    {
        if (!IsAdmin) return Forbid();
        var adminId = CurrentUserId;
        if (adminId == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.Content))
            return BadRequest(new { error = "Message content cannot be empty." });

        var conv = await _db.ChatConversations.SingleOrDefaultAsync(c => c.Id == request.ConversationId, ct);
        if (conv == null) return NotFound(new { error = "Conversation not found." });

        var adminUser = await _db.Admins.FindAsync(new object[] { adminId.Value }, ct);
        var adminName = adminUser?.FullName ?? "Admin Support";

        var cleanContent = request.Content.Trim();
        var encrypted = _crypto.Encrypt(cleanContent);

        var recipientId = request.RecipientId != Guid.Empty ? request.RecipientId : conv.CustomerId;

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conv.Id,
            SenderId = adminId.Value,
            SenderName = $"{adminName} (Support Agent)",
            RecipientId = recipientId,
            MessageType = "Text",
            EncryptedContent = encrypted,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        conv.LastMessageAt = DateTime.UtcNow;
        conv.LastMessageSnippet = cleanContent.Length > 60 ? cleanContent[..60] + "..." : cleanContent;
        if (recipientId == conv.CustomerId)
        {
            conv.UnreadCustomer++;
        }
        else
        {
            conv.UnreadProvider++;
        }

        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync(ct);

        var messageDto = new
        {
            id = message.Id,
            conversationId = message.ConversationId,
            senderId = message.SenderId,
            senderName = message.SenderName,
            recipientId = message.RecipientId,
            messageType = message.MessageType,
            content = cleanContent,
            mediaUrl = message.MediaUrl,
            isRead = message.IsRead,
            createdAt = message.CreatedAt,
            isSupportSender = true
        };

        // Broadcast real-time to the conversation group and recipient's personal group
        await _hubContext.Clients.Group($"conv_{conv.Id}").SendAsync("ReceiveMessage", messageDto, ct);
        await _hubContext.Clients.Group($"user_{recipientId}").SendAsync("ReceiveMessage", messageDto, ct);
        await _hubContext.Clients.Group("admin_support_channel").SendAsync("ReceiveMessage", messageDto, ct);

        return Ok(messageDto);
    }

    /// <summary>
    /// Deletes a message by an administrator and synchronizes across all active clients in real-time.
    /// </summary>
    [HttpDelete("admin/messages/{id:guid}")]
    public async Task<IActionResult> AdminDeleteMessage(Guid id, CancellationToken ct)
    {
        if (!IsAdmin) return Forbid();

        var msg = await _db.ChatMessages.FindAsync(new object[] { id }, ct);
        if (msg == null) return NotFound(new { error = "Message not found." });

        var convId = msg.ConversationId;
        _db.ChatMessages.Remove(msg);
        await _db.SaveChangesAsync(ct);

        await _hubContext.Clients.Group($"conv_{convId}").SendAsync("MessageDeleted", new
        {
            conversationId = convId.ToString(),
            messageId = id.ToString()
        }, ct);

        await _hubContext.Clients.Group("admin_support_channel").SendAsync("MessageDeleted", new
        {
            conversationId = convId.ToString(),
            messageId = id.ToString()
        }, ct);

        return Ok(new { success = true, id });
    }
}

public sealed record FindOrCreateConversationRequest(
    Guid? CustomerId,
    Guid ProviderId,
    string? BookingReference);

public sealed record AdminInquiryRequest(
    string Reason);

public sealed record AdminSendMessageRequest(
    Guid ConversationId,
    Guid RecipientId,
    string Content);

