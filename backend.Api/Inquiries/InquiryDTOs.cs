namespace TaskBridge.Api.Inquiries;

public sealed record CreateInquiryRequest(
    string Subject,
    string Category,
    string Message,
    string? Priority,
    List<string>? AttachmentUrls,
    Guid? UserId,
    string? UserName,
    string? UserRole
);

public sealed record AdminRespondInquiryRequest(
    string ResponseMessage,
    string Status, // "Responded" or "Resolved" or "InProgress"
    string? AdminName
);

public sealed record InquiryResponseDto(
    Guid Id,
    string InquiryReference,
    Guid? UserId,
    string UserName,
    string? UserEmail,
    string? UserPhone,
    string UserRole,
    string Subject,
    string Category,
    string Message,
    List<string> AttachmentUrls,
    string Priority,
    string Status,
    string? AdminResponse,
    string? RespondedByAdminName,
    DateTime? RespondedAt,
    DateTime CreatedAt,
    DateTime? UpdatedAt
);

public sealed record InquiriesSummaryResponseDto(
    List<InquiryResponseDto> Inquiries,
    int TotalCount,
    int OpenCount,
    int RespondedCount,
    int ResolvedCount
);
