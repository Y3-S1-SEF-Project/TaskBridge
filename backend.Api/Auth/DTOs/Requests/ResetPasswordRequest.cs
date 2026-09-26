using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record ResetPasswordRequest(
    [Required, EmailAddress] string Email,
    [Required, RegularExpression(@"^\d{6}$")] string Code,
    [Required, StringLength(128, MinimumLength = 8)] string NewPassword);
