using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record RegisterRequest(
    [Required, StringLength(100, MinimumLength = 2)] string FullName,
    [Required, EmailAddress, StringLength(255)] string Email,
    [Required, StringLength(24)] string Phone,
    [Required, StringLength(128, MinimumLength = 8)] string Password);
