using System.ComponentModel.DataAnnotations;

namespace TaskBridge.Api.Auth;

public sealed record ResendOtpRequest(
    [Required, EmailAddress] string Email);
