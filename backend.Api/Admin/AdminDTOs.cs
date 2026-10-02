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

