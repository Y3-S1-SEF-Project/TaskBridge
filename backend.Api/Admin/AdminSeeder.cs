using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Admin;

public static class AdminSeeder
{
    public static async Task SeedSuperAdminAsync(AuthDbContext db, IPasswordHasher<AppUser> hasher)
    {
        try
        {
            var adminUser = await db.Users.SingleOrDefaultAsync(u =>
                u.Email == "admin1@taskbridge.com" ||
                u.Email == "admin1" ||
                u.Phone == "admin1");

            if (adminUser is null)
            {
                adminUser = new AppUser
                {
                    Id = Guid.NewGuid(),
                    FullName = "Kavindu (Super Admin)",
                    Email = "admin1@taskbridge.com",
                    Phone = "admin1",
                    Role = "SuperAdmin",
                    IsEmailVerified = true,
                    CreatedAt = DateTimeOffset.UtcNow
                };

                adminUser.PasswordHash = hasher.HashPassword(adminUser, "admin1");
                db.Users.Add(adminUser);
                await db.SaveChangesAsync();
            }
            else
            {
                bool changed = false;
                if (adminUser.Role != "SuperAdmin")
                {
                    adminUser.Role = "SuperAdmin";
                    changed = true;
                }
                if (!adminUser.IsEmailVerified)
                {
                    adminUser.IsEmailVerified = true;
                    changed = true;
                }
                var verifyResult = hasher.VerifyHashedPassword(adminUser, adminUser.PasswordHash, "admin1");
                if (verifyResult == PasswordVerificationResult.Failed)
                {
                    adminUser.PasswordHash = hasher.HashPassword(adminUser, "admin1");
                    changed = true;
                }
                if (changed)
                {
                    await db.SaveChangesAsync();
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AdminSeeder] Notice: {ex.Message}");
        }
    }
}
