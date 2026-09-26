using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record VerifyOtpRequest(
    [Required, EmailAddress] string Email,
    [Required, RegularExpression(@"^\d{6}$")] string Code);
