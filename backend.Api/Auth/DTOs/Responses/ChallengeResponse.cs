namespace TaskBridge.Api.Auth;

public sealed record ChallengeResponse(
    string Email,
    DateTimeOffset ExpiresAt,
    string Message);
