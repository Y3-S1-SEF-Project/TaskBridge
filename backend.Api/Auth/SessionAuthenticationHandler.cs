using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Auth;

public sealed class SessionAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    AuthDbContext db)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var header = Request.Headers.Authorization.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.NoResult();

        var token = header[7..].Trim();
        if (string.IsNullOrWhiteSpace(token))
            return AuthenticateResult.Fail("Invalid session token.");

        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(
            x => x.SessionToken == token, Context.RequestAborted);

        if (user is null)
            return AuthenticateResult.Fail("Session expired or invalid.");

        var identity = new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Name, user.FullName),
            new Claim("phone", user.Phone),
        ], Scheme.Name);

        return AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name));
    }
}
