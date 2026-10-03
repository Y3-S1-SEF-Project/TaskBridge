namespace TaskBridge.Api.Notifications;

public interface INotificationService
{
    Task<NotificationResponseDto> SendNotificationAsync(CreateNotificationDto dto, CancellationToken ct = default);

    Task NotifyProposalReceivedAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string proposalReference,
        decimal rate,
        CancellationToken ct = default);

    Task NotifyProposalAcceptedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default);

    Task NotifyQuoteAcceptedByCustomerAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default);

    Task NotifyProposalDeclinedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string proposalReference,
        CancellationToken ct = default);

    Task NotifyCounterBidAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        decimal newRate,
        CancellationToken ct = default);

    Task NotifyCustomerCounterBidAsync(
        Guid? providerId,
        string? providerName,
        string customerName,
        string serviceTitle,
        string bookingReference,
        decimal newRate,
        CancellationToken ct = default);

    Task NotifyJobStartedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        CancellationToken ct = default);

    Task NotifyJobCompletedAsync(
        Guid? customerId,
        string? customerName,
        string providerName,
        string serviceTitle,
        string bookingReference,
        decimal calculatedPrice,
        CancellationToken ct = default);

    Task NotifyBookingCancelledAsync(
        Guid? targetUserId,
        string? targetUserName,
        string cancelledByName,
        string serviceTitle,
        string reference,
        CancellationToken ct = default);
}
