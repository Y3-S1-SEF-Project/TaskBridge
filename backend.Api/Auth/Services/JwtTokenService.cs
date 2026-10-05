using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using TaskBridge.Api.Admin;

namespace TaskBridge.Api.Auth;

public sealed class JwtTokenService
{
    private readonly IConfiguration _config;
    private readonly SymmetricSecurityKey _signingKey;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _durationDays;

    public JwtTokenService(IConfiguration config)
    {
        _config = config;
        var key = _config["Jwt:Key"] ?? "TaskBridge_SuperSecret_Jwt_Security_Key_2026_SEF_SLIIT!";
        _signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        _issuer = _config["Jwt:Issuer"] ?? "TaskBridgeApi";
        _audience = _config["Jwt:Audience"] ?? "TaskBridgeApp";
        _durationDays = int.TryParse(_config["Jwt:DurationDays"], out var d) ? d : 30;
    }

    public string GenerateUserToken(AppUser user)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Name, user.FullName),
            new(ClaimTypes.Role, user.Role ?? "User"),
            new("phone", user.Phone ?? ""),
        };

        return BuildToken(claims);
    }

    public string GenerateAdminToken(AdminUser admin)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, admin.Id.ToString()),
            new(ClaimTypes.Email, admin.Email),
            new(ClaimTypes.Name, admin.FullName),
            new(ClaimTypes.Role, admin.Role ?? "Admin"),
            new("username", admin.Username ?? ""),
        };

        return BuildToken(claims);
    }

    private string BuildToken(IEnumerable<Claim> claims)
    {
        var credentials = new SigningCredentials(_signingKey, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddDays(_durationDays);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = expires,
            Issuer = _issuer,
            Audience = _audience,
            SigningCredentials = credentials
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(tokenDescriptor);
        return handler.WriteToken(token);
    }
}
