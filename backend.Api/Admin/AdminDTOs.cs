using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Admin;

public sealed record AdminLoginRequest(
    [Required] string Identifier,
    [Required] string Password);

public sealed record AdminLoginResponse(
    string Token,
    string FullName,
    string Email,
    string Role,
    Guid Id,
    DateTimeOffset ExpiresAt);

public sealed record CreateAdminRequest(
    [Required, StringLength(100)] string FullName,
    [Required, EmailAddress] string Email,
    [Required, StringLength(128, MinimumLength = 4)] string Password,
    string Role = "Admin");

public sealed record UpdateAdminRequest(
    [Required, StringLength(100)] string FullName,
    [Required] string Role,
    bool IsActive = true,
    string? NewPassword = null);

public sealed record AdminUserDto(
    Guid Id,
    string FullName,
    string Email,
    string Role,
    bool IsActive,
    DateTimeOffset CreatedAt);

public sealed record InquiryItemDto(
    string InquiryNumber,
    string Customer,
    string Issue,
    string Provider,
    string Priority,
    string Status,
    DateTimeOffset CreatedAt);

public sealed record DayActivityDto(
    string Day,
    int Requests,
    int Bookings,
    int ProviderActive);

public sealed record DashboardStatsDto(
    int TotalRequests,
    string RequestsChange,
    int ActiveJobs,
    int JobsStartingToday,
    int CompletedJobs,
    string CompletionRate,
    int OpenInquiries,
    int InquiriesNeedingResponse,
    int AiWorkflows,
    string AiSuccessRate,
    int HumanReviews,
    int FailedWorkflows,
    int CompletionIssues,
    List<DayActivityDto> ServiceRequestsChart,
    List<DayActivityDto> ProviderActivityChart,
    List<InquiryItemDto> RecentInquiries);

public sealed record ServiceRequestItemDto(
    Guid Id,
    string Reference,
    string CustomerName,
    Guid? CustomerId,
    string ProviderName,
    Guid? ProviderId,
    string ServiceTitle,
    string Category,
    string Location,
    string PreferredSchedule,
    decimal Price,
    string RateType,
    string Status,
    string Urgency,
    string? Notes,
    DateTimeOffset CreatedAt,
    string? LinkedBookingReference);

public sealed record ServiceRequestsSummaryDto(
    int TotalRequests,
    int PendingCount,
    int AcceptedCount,
    int CompletedCount,
    int CancelledCount,
    List<string> AvailableCategories,
    List<ServiceRequestItemDto> Items);

public sealed record ProviderItemDto(
    string Id,
    Guid UserId,
    string Name,
    string Category,
    string Phone,
    string Location,
    double Rating,
    int CompletedJobs,
    string KycStatus,
    string AccountStatus,
    string? Bio,
    decimal HourlyRate,
    string? Skills,
    string? Services,
    DateTimeOffset JoinedDate);

public sealed record ProvidersSummaryDto(
    int TotalProviders,
    int VerifiedCount,
    int PendingKycCount,
    double AverageRating,
    List<string> AvailableCategories,
    List<ProviderItemDto> Items);

public sealed record CustomerItemDto(
    string Id,
    Guid UserId,
    string Name,
    string Email,
    string Phone,
    string District,
    int BookingsCount,
    decimal TotalSpent,
    string Status,
    DateTimeOffset JoinedDate);

public sealed record CustomersSummaryDto(
    int TotalCustomers,
    string ActiveRepeatRate,
    string AvgLifetimeValue,
    string AccountHealth,
    List<CustomerItemDto> Items);

public sealed record ReviewItemDto(
    string Id,
    Guid ReviewGuid,
    string BookingReference,
    string CustomerName,
    string ProviderName,
    string Service,
    int Rating,
    string Comment,
    string Sentiment,
    string Status,
    DateTimeOffset CreatedAt);

public sealed record ReviewsSummaryDto(
    int TotalReviews,
    double OverallRating,
    int FlaggedCount,
    string PositiveSentimentRate,
    List<ReviewItemDto> Items);

public sealed record UpdateReviewStatusRequest(
    [Required] string Status);

public sealed record BookingItemDto(
    Guid Id,
    string BookingReference,
    string ServiceTitle,
    string Category,
    string CustomerName,
    Guid? CustomerId,
    string ProviderName,
    Guid? ProviderId,
    string ScheduledWindow,
    string Location,
    decimal Price,
    string RateType,
    decimal? FinalPrice,
    string Status,
    int? DurationMinutes,
    string? Notes,
    DateTimeOffset CreatedAt);

public sealed record BookingsSummaryDto(
    int ActiveJobsCount,
    int ScheduledTodayCount,
    decimal TotalWorkFunds,
    string FormattedWorkFunds,
    int CompletedJobsCount,
    List<BookingItemDto> Items);

