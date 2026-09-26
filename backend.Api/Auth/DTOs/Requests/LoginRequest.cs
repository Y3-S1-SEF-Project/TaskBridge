using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record LoginRequest(
    [Required, StringLength(255)] string Identifier,
    [Required, StringLength(128)] string Password);
