namespace TaskBridge.Api.Auth;

public sealed record UserResponse(
    Guid Id,
    string FullName,
    string Email,
    string Phone,
    string? Address,
    string? Location,
    string? Preferences,
    string? ProfilePhotoUrl,
    bool IsProvider = false,
    string? ProviderCategory = null,
    string? ProviderSkills = null,
    string? ProviderServices = null,
    string? ProviderExperience = null,
    string? ProviderCertifications = null,
    string? ProviderServiceAreas = null,
    string? ProviderAvailability = null,
    string? ProviderBio = null,
    decimal? ProviderEarnings = null,
    decimal? ProviderHourlyRate = null);
