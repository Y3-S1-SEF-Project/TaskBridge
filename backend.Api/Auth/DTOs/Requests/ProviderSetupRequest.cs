namespace TaskBridge.Api.Auth;

public sealed record ProviderSetupRequest(
    string? Skills,
    string? Services,
    string? Experience,
    string? Certifications,
    string? ServiceAreas,
    string? Availability,
    string? Bio,
    string? Location = null,
    decimal? HourlyRate = null,
    string? Category = null,
    string? VerificationDocumentUrl = null,
    string? VerificationDocumentType = null);
