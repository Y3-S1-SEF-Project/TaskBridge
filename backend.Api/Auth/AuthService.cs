using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Auth;

public sealed class AuthService(
    AuthDbContext db,
    IPasswordHasher<AppUser> hasher,
    IEmailOtpSender emailSender,
    ILogger<AuthService> logger)
{
    public async Task<ChallengeResponse> Register(RegisterRequest request, CancellationToken ct)
    {
        AuthCrypto.ValidatePassword(request.Password);
        var name = request.FullName.Trim();
        if (name.Length < 2) throw new AuthProblem(400, "Enter your full name.");

        var email = request.Email.Trim().ToLowerInvariant();
        var phone = request.Phone.Trim();

        var existing = await db.Users.SingleOrDefaultAsync(x => x.Email == email, ct);
        if (existing is not null && existing.IsEmailVerified)
            throw new AuthProblem(400, "An account with this email address already exists. Please log in.");

        var user = existing ?? new AppUser
        {
            FullName = name,
            Email = email,
            Phone = phone,
            CreatedAt = DateTimeOffset.UtcNow,
        };

        user.FullName = name;
        user.Phone = phone;
        user.PasswordHash = hasher.HashPassword(user, request.Password);
        user.IsEmailVerified = false;

        var code = AuthCrypto.Code();
        user.EmailOtp = code;
        user.EmailOtpExpiresAt = DateTimeOffset.UtcNow.AddMinutes(10);
        user.UpdatedAt = DateTimeOffset.UtcNow;

        if (existing is null)
            db.Users.Add(user);

        await db.SaveChangesAsync(ct);

        await emailSender.SendOtpAsync(user.Email, user.FullName, code, ct);

        return new ChallengeResponse(
            user.Email,
            user.EmailOtpExpiresAt.Value,
            "A 6-digit verification code has been sent to your email.");
    }

    public async Task<AuthResponse> VerifyOtp(VerifyOtpRequest request, CancellationToken ct)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email, ct);

        if (user is null)
            throw new AuthProblem(400, "No pending registration found for this email.");

        if (string.IsNullOrWhiteSpace(user.EmailOtp) ||
            user.EmailOtp != request.Code.Trim() ||
            user.EmailOtpExpiresAt < DateTimeOffset.UtcNow)
        {
            throw new AuthProblem(400, "The verification code is incorrect or has expired. Please request a new code.");
        }

        user.IsEmailVerified = true;
        user.EmailOtp = null;
        user.EmailOtpExpiresAt = null;

        var token = AuthCrypto.Token();
        user.SessionToken = token;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync(ct);

        var isNewUser = string.IsNullOrWhiteSpace(user.Address);
        return new AuthResponse(
            token,
            DateTimeOffset.UtcNow.AddDays(30),
            MapUser(user),
            isNewUser);
    }

    public async Task<ChallengeResponse> ResendOtp(ResendOtpRequest request, CancellationToken ct)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email, ct);

        if (user is null)
            throw new AuthProblem(400, "No account found with this email.");

        var code = AuthCrypto.Code();
        user.EmailOtp = code;
        user.EmailOtpExpiresAt = DateTimeOffset.UtcNow.AddMinutes(10);
        user.UpdatedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync(ct);

        await emailSender.SendOtpAsync(user.Email, user.FullName, code, ct);

        return new ChallengeResponse(
            user.Email,
            user.EmailOtpExpiresAt.Value,
            "A fresh verification code has been sent to your email.");
    }

    public async Task<AuthResponse> Login(LoginRequest request, CancellationToken ct)
    {
        var id = request.Identifier.Trim();
        var user = await db.Users.SingleOrDefaultAsync(
            x => x.Email.ToLower() == id.ToLower() || x.Phone == id, ct);

        if (user is null)
            throw new AuthProblem(401, "The email/phone or password you entered is incorrect.");

        if (user.LockedUntil > DateTimeOffset.UtcNow)
            throw new AuthProblem(429, "Too many failed attempts. Try again in 15 minutes.");

        var result = hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (result == PasswordVerificationResult.Failed)
        {
            user.FailedLogins++;
            if (user.FailedLogins >= 5)
                user.LockedUntil = DateTimeOffset.UtcNow.AddMinutes(15);
            await db.SaveChangesAsync(ct);
            throw new AuthProblem(401, "The email/phone or password you entered is incorrect.");
        }

        user.FailedLogins = 0;
        user.LockedUntil = null;

        if (!user.IsEmailVerified)
        {
            var code = AuthCrypto.Code();
            user.EmailOtp = code;
            user.EmailOtpExpiresAt = DateTimeOffset.UtcNow.AddMinutes(10);
            await db.SaveChangesAsync(ct);
            await emailSender.SendOtpAsync(user.Email, user.FullName, code, ct);
            throw new AuthProblem(403, "Please verify your email address. A new code was sent to your email.");
        }

        var token = AuthCrypto.Token();
        user.SessionToken = token;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        return new AuthResponse(
            token,
            DateTimeOffset.UtcNow.AddDays(30),
            MapUser(user),
            IsNewUser: false);
    }

    public async Task<UserResponse> UpdateProfile(Guid userId, ProfileUpdateRequest request, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) throw new AuthProblem(404, "User not found.");

        if (!string.IsNullOrWhiteSpace(request.FullName)) user.FullName = request.FullName.Trim();
        if (!string.IsNullOrWhiteSpace(request.Address)) user.Address = request.Address.Trim();
        if (!string.IsNullOrWhiteSpace(request.Location)) user.Location = request.Location.Trim();
        if (!string.IsNullOrWhiteSpace(request.Preferences)) user.Preferences = request.Preferences.Trim();
        if (!string.IsNullOrWhiteSpace(request.ProfilePhotoUrl)) user.ProfilePhotoUrl = request.ProfilePhotoUrl.Trim();

        user.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        return MapUser(user);
    }

    public async Task<UserResponse?> GetUserByToken(string token, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.SessionToken == token, ct);
        return user is null ? null : MapUser(user);
    }

    public async Task Logout(Guid userId, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([userId], ct);
        if (user is not null)
        {
            user.SessionToken = null;
            await db.SaveChangesAsync(ct);
        }
    }

    public static UserResponse MapUser(AppUser u) => new(
        u.Id,
        u.FullName,
        u.Email,
        u.Phone,
        u.Address,
        u.Location,
        u.Preferences,
        u.ProfilePhotoUrl);
}
