using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Chat;

[Authorize]
public sealed class ChatHub : Hub
{
    private readonly AuthDbContext _db;
    private readonly ChatCrypto _crypto;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(AuthDbContext db, ChatCrypto crypto, ILogger<ChatHub> logger)
    {
        _db = db;
        _crypto = crypto;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        _logger.LogInformation("SignalR ChatHub: User {UserId} connected (ConnectionId: {ConnId})", userId, Context.ConnectionId);
        
        // Add to user's personal channel group for targeted messages
        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.UserIdentifier;
        _logger.LogInformation("SignalR ChatHub: User {UserId} disconnected", userId);
        await base.OnDisconnectedAsync(exception);
    }

    public async Task JoinConversation(string conversationId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"conv_{conversationId}");
    }

    public async Task LeaveConversation(string conversationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"conv_{conversationId}");
    }

    /// <summary>
    /// Sends a text message or image attachment securely in real-time.
    /// The message is encrypted at rest using AES-256 before being saved to PostgreSQL.
    /// </summary>
    public async Task SendMessage(
        string conversationIdStr,
        string recipientIdStr,
        string content,
        string? mediaUrl,
        string messageType = "Text")
    {
        var senderIdStr = Context.UserIdentifier;
        if (!Guid.TryParse(senderIdStr, out var senderId))
        {
            throw new HubException("Unauthorized sender.");
        }

        if (!Guid.TryParse(conversationIdStr, out var conversationId) ||
            !Guid.TryParse(recipientIdStr, out var recipientId))
        {
            throw new HubException("Invalid conversation or recipient ID.");
        }

        var senderName = Context.User?.FindFirst(ClaimTypes.Name)?.Value ?? "User";

        var conv = await _db.ChatConversations.SingleOrDefaultAsync(c => c.Id == conversationId);
        if (conv == null)
        {
            throw new HubException("Conversation not found.");
        }

        // Verify sender is a participant
        if (conv.CustomerId != senderId && conv.ProviderId != senderId)
        {
            throw new HubException("You are not a participant in this conversation.");
        }

        // Encrypt the content at-rest
        var cleanContent = content?.Trim() ?? string.Empty;
        var encrypted = _crypto.Encrypt(cleanContent);

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conversationId,
            SenderId = senderId,
            SenderName = senderName,
            RecipientId = recipientId,
            MessageType = string.IsNullOrWhiteSpace(messageType) ? "Text" : messageType,
            EncryptedContent = encrypted,
            MediaUrl = mediaUrl,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        // Update conversation metadata
        conv.LastMessageAt = DateTime.UtcNow;
        conv.LastMessageSnippet = message.MessageType == "Image" ? "📷 Sent an image" : (cleanContent.Length > 60 ? cleanContent[..60] + "..." : cleanContent);
        if (senderId == conv.CustomerId)
        {
            conv.UnreadProvider++;
        }
        else
        {
            conv.UnreadCustomer++;
        }

        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync();

        var messageDto = new
        {
            id = message.Id,
            conversationId = message.ConversationId,
            senderId = message.SenderId,
            senderName = message.SenderName,
            recipientId = message.RecipientId,
            messageType = message.MessageType,
            content = cleanContent, // Deliver decrypted to live connected socket
            mediaUrl = message.MediaUrl,
            isRead = message.IsRead,
            createdAt = message.CreatedAt
        };

        // Broadcast to conversation group and directly to recipient's personal group
        await Clients.Group($"conv_{conversationId}").SendAsync("ReceiveMessage", messageDto);
        await Clients.Group($"user_{recipientId}").SendAsync("ReceiveMessage", messageDto);
    }

    /// <summary>
    /// Broadcasts typing indicator to the recipient.
    /// </summary>
    public async Task SendTyping(string conversationIdStr, string recipientIdStr, bool isTyping)
    {
        var senderIdStr = Context.UserIdentifier;
        if (!Guid.TryParse(senderIdStr, out var senderId)) return;

        var senderName = Context.User?.FindFirst(ClaimTypes.Name)?.Value ?? "User";

        await Clients.Group($"user_{recipientIdStr}").SendAsync("UserTyping", new
        {
            conversationId = conversationIdStr,
            userId = senderId,
            userName = senderName,
            isTyping
        });
    }

    /// <summary>
    /// Marks all unread messages in a conversation as read by the caller.
    /// </summary>
    public async Task MarkAsRead(string conversationIdStr)
    {
        var userIdStr = Context.UserIdentifier;
        if (!Guid.TryParse(userIdStr, out var userId) || !Guid.TryParse(conversationIdStr, out var convId)) return;

        var conv = await _db.ChatConversations.SingleOrDefaultAsync(c => c.Id == convId);
        if (conv != null)
        {
            if (userId == conv.CustomerId)
            {
                conv.UnreadCustomer = 0;
            }
            else if (userId == conv.ProviderId)
            {
                conv.UnreadProvider = 0;
            }

            var unreadMessages = await _db.ChatMessages
                .Where(m => m.ConversationId == convId && !m.IsRead && m.SenderId != userId)
                .ToListAsync();

            if (unreadMessages.Count > 0)
            {
                foreach (var msg in unreadMessages)
                {
                    msg.IsRead = true;
                }

                await _db.SaveChangesAsync();
                await Clients.Group($"conv_{convId}").SendAsync("MessagesRead", new { conversationId = conversationIdStr, readBy = userId });
            }
        }
    }

    /// <summary>
    /// Deletes a message and broadcasts the deletion to conversation participants.
    /// </summary>
    public async Task DeleteMessage(string conversationIdStr, string messageIdStr)
    {
        var userIdStr = Context.UserIdentifier;
        if (!Guid.TryParse(userIdStr, out var userId) ||
            !Guid.TryParse(messageIdStr, out var msgId) ||
            !Guid.TryParse(conversationIdStr, out var convId)) return;

        var msg = await _db.ChatMessages.FindAsync(msgId);
        if (msg != null && (msg.SenderId == userId || msg.RecipientId == userId))
        {
            _db.ChatMessages.Remove(msg);
            await _db.SaveChangesAsync();
            await Clients.Group($"conv_{convId}").SendAsync("MessageDeleted", new { conversationId = conversationIdStr, messageId = messageIdStr });
        }
    }
}
