using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Auth;

public sealed class AuthService(
    AuthDbContext db,
    IPasswordHasher<AppUser> hasher,
    IEmailOtpSender emailSender,
    IProfileImageService imageService,
    JwtTokenService jwt,
    ILogger<AuthService> logger)
{
    public async Task<ChallengeResponse> Register(RegisterRequest request, CancellationToken ct)
    {
        AuthCrypto.ValidatePassword(request.Password);
        var name = request.FullName.Trim();
        if (name.Length < 2) throw new AuthProblem(400, "Enter your full name.");

        var email = request.Email.Trim().ToLowerInvariant();
        var phone = request.Phone.Trim();
        var cleanPhone = Regex.Replace(phone, @"[\s()+-]", "");
        var localPhone = cleanPhone.StartsWith("94") ? "0" + cleanPhone[2..] : cleanPhone;
        var intlPhone = cleanPhone.StartsWith("0") ? "94" + cleanPhone[1..] : cleanPhone;

        var existingEmail = await db.Users.SingleOrDefaultAsync(x => x.Email == email, ct);
        var existingPhone = await db.Users.FirstOrDefaultAsync(
            x => x.IsEmailVerified && (x.Phone == phone || x.Phone == localPhone || x.Phone == intlPhone || x.Phone == cleanPhone), ct);

        if (existingEmail is not null && existingEmail.IsEmailVerified && existingPhone is not null && existingPhone.Id != existingEmail.Id)
        {
            throw new AuthProblem(400, "This email address and mobile number are already in use. Please use a different email or mobile number.");
        }

        if (existingEmail is not null && existingEmail.IsEmailVerified)
        {
            throw new AuthProblem(400, "This email address is already in use. Please use a different email address.");
        }

        if (existingPhone is not null && (existingEmail is null || existingPhone.Id != existingEmail.Id))
        {
            throw new AuthProblem(400, "This mobile number is already in use. Please use a different mobile number.");
        }

        var user = existingEmail ?? new AppUser
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

        if (existingEmail is null)
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

        var token = jwt.GenerateUserToken(user);
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
        var idLower = id.ToLowerInvariant();
        var clean = Regex.Replace(id, @"[\s()+-]", "");
        var local = clean.StartsWith("94") ? "0" + clean[2..] : clean;
        var intl = clean.StartsWith("0") ? "94" + clean[1..] : clean;

        var users = await db.Users
            .Where(x => x.Email.ToLower() == idLower ||
                        x.Phone == id ||
                        x.Phone == local ||
                        x.Phone == intl ||
                        x.Phone == clean)
            .OrderByDescending(x => x.IsEmailVerified)
            .ThenByDescending(x => x.CreatedAt)
            .ToListAsync(ct);

        var user = users.FirstOrDefault();

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

        var token = jwt.GenerateUserToken(user);
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
        if (request.Address is not null) user.Address = CleanLocationString(request.Address);
        if (request.Location is not null) user.Location = CleanLocationString(request.Location);
        if (request.Preferences is not null) user.Preferences = string.IsNullOrWhiteSpace(request.Preferences) ? null : request.Preferences.Trim();
        if (!string.IsNullOrWhiteSpace(request.ProfilePhotoUrl)) user.ProfilePhotoUrl = request.ProfilePhotoUrl.Trim();

        user.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        return MapUser(user);
    }

    public async Task<UserResponse> UploadProfilePhoto(Guid userId, IFormFile file, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) throw new AuthProblem(404, "User not found.");

        var photoUrl = await imageService.UploadProfilePhotoAsync(file, userId, ct);
        user.ProfilePhotoUrl = photoUrl;
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

    public async Task<UserResponse> UpdateProviderProfile(Guid userId, ProviderSetupRequest req, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) throw new AuthProblem(404, "User not found.");

        user.IsProvider = true;
        if (req.Category != null) user.ProviderCategory = req.Category.Trim();
        if (req.Skills != null) user.ProviderSkills = req.Skills.Trim();
        if (req.Services != null) user.ProviderServices = req.Services.Trim();
        if (req.Experience != null) user.ProviderExperience = req.Experience.Trim();
        if (req.Certifications != null) user.ProviderCertifications = req.Certifications.Trim();
        if (req.ServiceAreas != null) user.ProviderServiceAreas = req.ServiceAreas.Trim();
        if (req.Availability != null) user.ProviderAvailability = req.Availability.Trim();
        if (req.Bio != null) user.ProviderBio = req.Bio.Trim();
        if (req.Location != null) user.Location = req.Location.Trim();
        if (req.HourlyRate.HasValue && req.HourlyRate.Value > 0) user.ProviderHourlyRate = req.HourlyRate.Value;
        if (req.VerificationDocumentUrl != null)
        {
            if (string.IsNullOrWhiteSpace(req.VerificationDocumentUrl))
            {
                user.ProviderVerificationDocumentUrl = null;
                user.ProviderVerificationStatus = "Unverified";
            }
            else
            {
                user.ProviderVerificationDocumentUrl = req.VerificationDocumentUrl.Trim();
                user.ProviderVerificationStatus = "Pending";
            }
        }
        user.UpdatedAt = DateTimeOffset.UtcNow;

        var resolvedCategory = !string.IsNullOrWhiteSpace(req.Category)
            ? req.Category.Trim()
            : (!string.IsNullOrWhiteSpace(req.Services) ? req.Services.Trim() : (!string.IsNullOrWhiteSpace(req.Skills) ? req.Skills.Trim() : "General"));

        // Upsert into dedicated providers table
        var provider = await db.Providers.SingleOrDefaultAsync(p => p.UserId == userId, ct);
        if (provider is null)
        {
            provider = new ProviderProfile
            {
                UserId = userId,
                Category = resolvedCategory,
                Skills = req.Skills?.Trim(),
                Services = req.Services?.Trim(),
                Experience = req.Experience?.Trim(),
                Certifications = req.Certifications?.Trim(),
                ServiceAreas = req.ServiceAreas?.Trim() ?? req.Location?.Trim(),
                Availability = req.Availability?.Trim(),
                Bio = req.Bio?.Trim(),
                HourlyRate = req.HourlyRate.HasValue && req.HourlyRate.Value > 0 ? req.HourlyRate.Value : (user.ProviderHourlyRate ?? 2500m),
                VerificationDocumentUrl = req.VerificationDocumentUrl?.Trim(),
                VerificationDocumentType = req.VerificationDocumentType?.Trim() ?? "National ID",
                VerificationStatus = !string.IsNullOrWhiteSpace(req.VerificationDocumentUrl) ? "Pending" : "Unverified",
                VerificationSubmittedAt = !string.IsNullOrWhiteSpace(req.VerificationDocumentUrl) ? DateTimeOffset.UtcNow : null,
                CreatedAt = DateTimeOffset.UtcNow,
                IsActive = true
            };
            db.Providers.Add(provider);
        }
        else
        {
            if (req.Category != null) provider.Category = req.Category.Trim();
            else if (string.IsNullOrWhiteSpace(provider.Category) || provider.Category == "General") provider.Category = resolvedCategory;
            if (req.Skills != null) provider.Skills = req.Skills.Trim();
            if (req.Services != null) provider.Services = req.Services.Trim();
            if (req.Experience != null) provider.Experience = req.Experience.Trim();
            if (req.Certifications != null) provider.Certifications = req.Certifications.Trim();
            if (req.ServiceAreas != null) provider.ServiceAreas = req.ServiceAreas.Trim();
            else if (req.Location != null) provider.ServiceAreas = req.Location.Trim();
            if (req.Availability != null) provider.Availability = req.Availability.Trim();
            if (req.Bio != null) provider.Bio = req.Bio.Trim();
            if (req.HourlyRate.HasValue && req.HourlyRate.Value > 0) provider.HourlyRate = req.HourlyRate.Value;
            if (req.VerificationDocumentUrl != null)
            {
                if (string.IsNullOrWhiteSpace(req.VerificationDocumentUrl))
                {
                    provider.VerificationDocumentUrl = null;
                    provider.VerificationStatus = "Unverified";
                    provider.VerificationSubmittedAt = null;
                }
                else
                {
                    provider.VerificationDocumentUrl = req.VerificationDocumentUrl.Trim();
                    provider.VerificationDocumentType = req.VerificationDocumentType?.Trim() ?? provider.VerificationDocumentType ?? "National ID";
                    provider.VerificationStatus = "Pending";
                    provider.VerificationSubmittedAt = DateTimeOffset.UtcNow;
                }
            }
            provider.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await db.SaveChangesAsync(ct);
        return MapUser(user, provider);
    }

    public async Task<UserResponse> UploadCertification(Guid userId, IFormFile file, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([userId], ct);
        if (user is null) throw new AuthProblem(404, "User not found.");

        var certUrl = await imageService.UploadProfilePhotoAsync(file, userId, ct);
        user.ProviderCertifications = string.IsNullOrWhiteSpace(user.ProviderCertifications)
            ? certUrl
            : $"{user.ProviderCertifications},{certUrl}";
        user.UpdatedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync(ct);
        return MapUser(user);
    }

    public static string? CleanLocationString(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return null;
        var cleaned = System.Text.RegularExpressions.Regex.Replace(
            input,
            @"\b[A-Za-z0-9]{2,8}\+[A-Za-z0-9]{1,4}\b",
            "",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        cleaned = System.Text.RegularExpressions.Regex.Replace(cleaned, @"(\s*,\s*)+", ", ");
        cleaned = cleaned.Trim(' ', ',');
        return string.IsNullOrWhiteSpace(cleaned) ? null : cleaned;
    }

    public static UserResponse MapUser(AppUser u, ProviderProfile? p = null)
    {
        var prov = p ?? u.ProviderProfile;
        var isVer = prov?.IsVerified ?? u.IsVerifiedProvider;
        var verStatus = prov?.VerificationStatus ?? u.ProviderVerificationStatus ?? (isVer ? "Approved" : "Unverified");
        var docUrl = prov?.VerificationDocumentUrl ?? u.ProviderVerificationDocumentUrl;
        var docType = prov?.VerificationDocumentType;

        return new(
            u.Id,
            u.FullName,
            u.Email,
            u.Phone,
            CleanLocationString(u.Address),
            CleanLocationString(u.Location),
            u.Preferences,
            u.ProfilePhotoUrl,
            u.IsProvider,
            u.ProviderCategory,
            u.ProviderSkills,
            u.ProviderServices,
            u.ProviderExperience,
            u.ProviderCertifications,
            u.ProviderServiceAreas,
            u.ProviderAvailability,
            u.ProviderBio,
            u.ProviderEarnings,
            u.ProviderHourlyRate ?? 2500m,
            u.Role ?? "User",
            isVer,
            verStatus,
            docUrl,
            docType);
    }
}
