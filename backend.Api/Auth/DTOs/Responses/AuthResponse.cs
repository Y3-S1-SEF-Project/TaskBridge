namespace TaskBridge.Api.Auth;

public sealed record AuthResponse(
    string AccessToken,
    DateTimeOffset ExpiresAt,
    UserResponse User,
    bool IsNewUser);
