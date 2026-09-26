namespace TaskBridge.Api.Auth;

public sealed class AuthProblem(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
