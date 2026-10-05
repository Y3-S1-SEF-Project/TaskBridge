using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Notifications;

[ApiController]
[Route("api/notifications")]
public sealed class NotificationsController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly INotificationService _notificationService;
    private readonly ILogger<NotificationsController> _logger;

    public NotificationsController(
        AuthDbContext db,
        INotificationService notificationService,
        ILogger<NotificationsController> logger)
    {
        _db = db;
        _notificationService = notificationService;
        _logger = logger;
    }

    /// <summary>
    /// Fetches all notifications for a specific user (either customer or provider), sorted newest first.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetNotifications(
        [FromQuery] Guid? userId,
        [FromQuery] string? userName,
        [FromQuery] string? role,
        [FromQuery] bool? unreadOnly,
        [FromQuery] int limit = 50,
        CancellationToken ct = default)
    {
        try
        {
            var resolvedUserId = userId ?? GetCurrentUserId();
            var resolvedUserName = userName?.Trim().ToLowerInvariant();

            var query = _db.Notifications.AsNoTracking().AsQueryable();

            if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty && !string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value || (n.UserName != null && n.UserName.ToLower() == resolvedUserName));
            }
            else if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty)
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value);
            }
            else if (!string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserName != null && n.UserName.ToLower() == resolvedUserName);
            }

            if (!string.IsNullOrWhiteSpace(role))
            {
                var cleanRole = role.Trim().ToLowerInvariant();
                query = query.Where(n => n.TargetRole == null || n.TargetRole == "" || n.TargetRole.ToLower() == cleanRole);
            }

            if (unreadOnly == true)
            {
                query = query.Where(n => !n.IsRead);
            }

            var list = await query
                .OrderByDescending(n => n.CreatedAt)
                .Take(Math.Min(limit, 100))
                .ToListAsync(ct);

            var result = list.Select(MapToResponse).ToList();
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving notifications");
            return StatusCode(500, new { message = "An error occurred while fetching notifications." });
        }
    }

    /// <summary>
    /// Gets the count of unread notifications for a user.
    /// </summary>
    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount(
        [FromQuery] Guid? userId,
        [FromQuery] string? userName,
        [FromQuery] string? role,
        CancellationToken ct = default)
    {
        try
        {
            var resolvedUserId = userId ?? GetCurrentUserId();
            var resolvedUserName = userName?.Trim().ToLowerInvariant();

            var query = _db.Notifications.AsNoTracking().Where(n => !n.IsRead);

            if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty && !string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value || (n.UserName != null && n.UserName.ToLower() == resolvedUserName));
            }
            else if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty)
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value);
            }
            else if (!string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserName != null && n.UserName.ToLower() == resolvedUserName);
            }

            if (!string.IsNullOrWhiteSpace(role))
            {
                var cleanRole = role.Trim().ToLowerInvariant();
                query = query.Where(n => n.TargetRole == null || n.TargetRole == "" || n.TargetRole.ToLower() == cleanRole);
            }

            var count = await query.CountAsync(ct);
            return Ok(new UnreadCountResponseDto { UnreadCount = count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting unread notification count");
            return StatusCode(500, new { message = "An error occurred while fetching unread count." });
        }
    }

    /// <summary>
    /// Marks a specific notification as read.
    /// </summary>
    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> MarkAsRead(Guid id, CancellationToken ct = default)
    {
        try
        {
            var item = await _db.Notifications.FirstOrDefaultAsync(n => n.Id == id, ct);
            if (item == null)
            {
                return NotFound(new { message = "Notification not found." });
            }

            item.IsRead = true;
            await _db.SaveChangesAsync(ct);
            return Ok(new { success = true, id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking notification {Id} as read", id);
            return StatusCode(500, new { message = "An error occurred while updating notification." });
        }
    }

    /// <summary>
    /// Marks all notifications as read for a given user.
    /// </summary>
    [HttpPut("mark-all-read")]
    public async Task<IActionResult> MarkAllAsRead(
        [FromQuery] Guid? userId,
        [FromQuery] string? userName,
        CancellationToken ct = default)
    {
        try
        {
            var resolvedUserId = userId ?? GetCurrentUserId();
            var resolvedUserName = userName?.Trim().ToLowerInvariant();

            var query = _db.Notifications.Where(n => !n.IsRead);

            if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty && !string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value || (n.UserName != null && n.UserName.ToLower() == resolvedUserName));
            }
            else if (resolvedUserId.HasValue && resolvedUserId != Guid.Empty)
            {
                query = query.Where(n => n.UserId == resolvedUserId.Value);
            }
            else if (!string.IsNullOrEmpty(resolvedUserName))
            {
                query = query.Where(n => n.UserName != null && n.UserName.ToLower() == resolvedUserName);
            }

            var unread = await query.ToListAsync(ct);
            foreach (var item in unread)
            {
                item.IsRead = true;
            }

            await _db.SaveChangesAsync(ct);
            return Ok(new { success = true, markedCount = unread.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking all notifications as read");
            return StatusCode(500, new { message = "An error occurred while updating notifications." });
        }
    }

    /// <summary>
    /// Deletes a specific notification.
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteNotification(Guid id, CancellationToken ct = default)
    {
        try
        {
            var item = await _db.Notifications.FirstOrDefaultAsync(n => n.Id == id, ct);
            if (item == null)
            {
                return NotFound(new { message = "Notification not found." });
            }

            _db.Notifications.Remove(item);
            await _db.SaveChangesAsync(ct);
            return Ok(new { success = true, message = "Notification deleted." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting notification {Id}", id);
            return StatusCode(500, new { message = "An error occurred while deleting notification." });
        }
    }

    private Guid? GetCurrentUserId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(claim, out var guid) ? guid : null;
    }

    private static NotificationResponseDto MapToResponse(NotificationEntity entity)
    {
        object? metadata = null;
        if (!string.IsNullOrWhiteSpace(entity.MetadataJson))
        {
            try
            {
                metadata = JsonSerializer.Deserialize<object>(entity.MetadataJson);
            }
            catch { }
        }

        return new NotificationResponseDto
        {
            Id = entity.Id,
            UserId = entity.UserId,
            UserName = entity.UserName,
            TargetRole = entity.TargetRole,
            Title = entity.Title,
            Message = entity.Message,
            Type = entity.Type,
            ReferenceId = entity.ReferenceId,
            ReferenceType = entity.ReferenceType,
            Metadata = metadata,
            IsRead = entity.IsRead,
            CreatedAt = entity.CreatedAt
        };
    }
}
