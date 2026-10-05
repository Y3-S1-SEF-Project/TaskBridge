using System.Text.Json;
using Microsoft.AspNetCore.SignalR;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Notifications;

public sealed class NotificationService : INotificationService
{
    private readonly AuthDbContext _db;
    private readonly IHubContext<NotificationHub> _hub;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        AuthDbContext db,
        IHubContext<NotificationHub> hub,
        ILogger<NotificationService> logger)
    {
        _db = db;
        _hub = hub;
        _logger = logger;
    }

    public async Task<NotificationResponseDto> SendNotificationAsync(CreateNotificationDto dto, CancellationToken ct = default)
    {
        var entity = new NotificationEntity
        {
            Id = Guid.NewGuid(),
            UserId = dto.UserId,
            UserName = dto.UserName,
            TargetRole = dto.TargetRole,
            Title = dto.Title,
            Message = dto.Message,
            Type = dto.Type,
            ReferenceId = dto.ReferenceId,
            ReferenceType = dto.ReferenceType,
            MetadataJson = dto.Metadata != null ? JsonSerializer.Serialize(dto.Metadata) : null,
            IsRead = false,
            CreatedAt = DateTimeOffset.UtcNow
        };

        _db.Notifications.Add(entity);
        await _db.SaveChangesAsync(ct);

        var response = MapToResponse(entity);

        // Dispatch via SignalR to target user (role-scoped group delivery to prevent notifying the wrong role)
        try
        {
            var targetGroups = new List<string>();

            if (!string.IsNullOrWhiteSpace(dto.TargetRole))
            {
                var cleanRole = dto.TargetRole.Trim().ToLowerInvariant();
                if (dto.UserId.HasValue && dto.UserId != Guid.Empty)
                {
                    targetGroups.Add($"user_{dto.UserId.Value}_{cleanRole}");
                }

                if (!string.IsNullOrWhiteSpace(dto.UserName))
                {
                    var clean = dto.UserName.Trim().ToLowerInvariant().Replace(" ", "_");
                    targetGroups.Add($"name_{clean}_{cleanRole}");
                }

                if (targetGroups.Count == 0)
                {
                    targetGroups.Add($"role_{cleanRole}");
                }
            }
            else
            {
                if (dto.UserId.HasValue && dto.UserId != Guid.Empty)
                {
                    targetGroups.Add($"user_{dto.UserId.Value}");
                }

                if (!string.IsNullOrWhiteSpace(dto.UserName))
                {
                    var clean = dto.UserName.Trim().ToLowerInvariant().Replace(" ", "_");
                    targetGroups.Add($"name_{clean}");
                }
            }

            if (targetGroups.Count > 0)
            {
                await _hub.Clients.Groups(targetGroups).SendAsync("ReceiveNotification", response, ct);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to deliver real-time SignalR notification {NotificationId}", entity.Id);
        }

        return response;
    }

    public Task NotifyProposalReceivedAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string proposalReference,
        decimal rate,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = providerId,
            UserName = providerName,
            TargetRole = "provider",
            Title = "New Job Proposal",
            Message = $"{customerName} sent you a proposal for {serviceTitle} (Rs. {rate:F0})",
            Type = "ProposalReceived",
            ReferenceId = proposalReference,
            ReferenceType = "Proposal",
            Metadata = new { customerName, serviceTitle, rate, proposalReference }
        }, ct);
    }

    public Task NotifyProposalAcceptedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = customerId,
            UserName = customerName,
            TargetRole = "customer",
            Title = "Proposal Accepted!",
            Message = $"{providerName} accepted your request for {serviceTitle}! Booking #{bookingReference} is confirmed.",
            Type = "ProposalAccepted",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { providerName, serviceTitle, bookingReference }
        }, ct);
    }

    public Task NotifyQuoteAcceptedByCustomerAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = providerId,
            UserName = providerName,
            TargetRole = "provider",
            Title = "Quote Accepted!",
            Message = $"{customerName} accepted your quote for {serviceTitle}! Booking #{bookingReference} is confirmed.",
            Type = "QuoteAccepted",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { customerName, serviceTitle, bookingReference }
        }, ct);
    }

    public Task NotifyProposalDeclinedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string proposalReference,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = customerId,
            UserName = customerName,
            TargetRole = "customer",
            Title = "Proposal Update",
            Message = $"{providerName} was unable to accept the proposal for {serviceTitle} (#{proposalReference}).",
            Type = "ProposalDeclined",
            ReferenceId = proposalReference,
            ReferenceType = "Proposal",
            Metadata = new { providerName, serviceTitle, proposalReference }
        }, ct);
    }

    public Task NotifyCounterBidAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        decimal newRate,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = customerId,
            UserName = customerName,
            TargetRole = "customer",
            Title = "New Counter-Offer Received",
            Message = $"{providerName} submitted an updated quote of Rs. {newRate:F0} for {serviceTitle}.",
            Type = "CounterBid",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { providerName, serviceTitle, bookingReference, newRate }
        }, ct);
    }

    public Task NotifyCustomerCounterBidAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string bookingReference,
        decimal newRate,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = providerId,
            UserName = providerName,
            TargetRole = "provider",
            Title = "New Offer from Customer",
            Message = $"{customerName} sent an updated offer of Rs. {newRate:F0} for {serviceTitle} (#{bookingReference}).",
            Type = "CounterBid",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { customerName, serviceTitle, bookingReference, newRate }
        }, ct);
    }

    public Task NotifyJobStartedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = customerId,
            UserName = customerName,
            TargetRole = "customer",
            Title = "Job In Progress",
            Message = $"{providerName} has arrived on-site and started work on #{bookingReference}.",
            Type = "JobStarted",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { providerName, serviceTitle, bookingReference }
        }, ct);
    }

    public Task NotifyJobCompletedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        decimal calculatedPrice,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = customerId,
            UserName = customerName,
            TargetRole = "customer",
            Title = "Job Completed",
            Message = $"{providerName} finished working on {serviceTitle}! Tap to verify photos, review, and complete payment.",
            Type = "JobCompleted",
            ReferenceId = bookingReference,
            ReferenceType = "Booking",
            Metadata = new { providerName, serviceTitle, bookingReference, calculatedPrice }
        }, ct);
    }

    public Task NotifyBookingCancelledAsync(
        Guid? targetUserId,
        string? targetUserName,
        string cancelledByName,
        string serviceTitle,
        string reference,
        CancellationToken ct = default)
    {
        return SendNotificationAsync(new CreateNotificationDto
        {
            UserId = targetUserId,
            UserName = targetUserName,
            Title = "Booking Cancelled",
            Message = $"{cancelledByName} cancelled {serviceTitle} (#{reference}).",
            Type = "BookingCancelled",
            ReferenceId = reference,
            ReferenceType = reference.StartsWith("PR-", StringComparison.OrdinalIgnoreCase) ? "Proposal" : "Booking",
            Metadata = new { cancelledByName, serviceTitle, reference }
        }, ct);
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
