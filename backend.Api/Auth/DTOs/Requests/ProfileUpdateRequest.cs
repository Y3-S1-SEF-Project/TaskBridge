namespace TaskBridge.Api.Auth;

public sealed record ProfileUpdateRequest(
    string? FullName,
    string? Address,
    string? Location,
    string? Preferences,
    string? ProfilePhotoUrl);
