using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record ForgotPasswordRequest(
    [Required, EmailAddress] string Email);
