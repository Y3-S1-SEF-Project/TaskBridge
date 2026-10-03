using System.Security.Claims;
using Microsoft.AspNetCore.SignalR;

namespace TaskBridge.Api.Notifications;

public sealed class NotificationHub : Hub
{
    private readonly ILogger<NotificationHub> _logger;

    public NotificationHub(ILogger<NotificationHub> logger)
    {
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        _logger.LogInformation("SignalR NotificationHub connected: User {UserId}, ConnectionId {ConnId}", userId, Context.ConnectionId);

        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
        }

        var userName = Context.User?.Identity?.Name;
        if (!string.IsNullOrEmpty(userName))
        {
            var cleanName = userName.Trim().ToLowerInvariant().Replace(" ", "_");
            await Groups.AddToGroupAsync(Context.ConnectionId, $"name_{cleanName}");
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.UserIdentifier;
        _logger.LogInformation("SignalR NotificationHub disconnected: User {UserId}", userId);
        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Explicitly registers client identity into user-specific and role-specific channels.
    /// Helpful when authenticating dynamically or switching profiles (e.g. Customer <-> Provider).
    /// </summary>
    public async Task RegisterChannel(string? userId, string? userName, string? role)
    {
        if (!string.IsNullOrWhiteSpace(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId.Trim()}");
            _logger.LogInformation("Client {ConnId} joined channel user_{UserId}", Context.ConnectionId, userId.Trim());
        }

        if (!string.IsNullOrWhiteSpace(userName))
        {
            var clean = userName.Trim().ToLowerInvariant().Replace(" ", "_");
            await Groups.AddToGroupAsync(Context.ConnectionId, $"name_{clean}");
            _logger.LogInformation("Client {ConnId} joined channel name_{Clean}", Context.ConnectionId, clean);
        }

        if (!string.IsNullOrWhiteSpace(role))
        {
            var cleanRole = role.Trim().ToLowerInvariant();
            await Groups.AddToGroupAsync(Context.ConnectionId, $"role_{cleanRole}");
            _logger.LogInformation("Client {ConnId} joined channel role_{Role}", Context.ConnectionId, cleanRole);
        }
    }
}
