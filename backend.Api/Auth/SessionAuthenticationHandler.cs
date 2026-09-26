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
        string? token = null;
        var header = Request.Headers.Authorization.ToString();
        if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = header[7..].Trim();
        }
        else if (Request.Query.TryGetValue("access_token", out var queryToken))
        {
            token = queryToken.ToString().Trim();
        }

        if (string.IsNullOrWhiteSpace(token))
            return AuthenticateResult.NoResult();

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
