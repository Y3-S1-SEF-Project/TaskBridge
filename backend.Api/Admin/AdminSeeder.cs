using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Admin;

public static class AdminSeeder
{
    public static async Task SeedSuperAdminAsync(AuthDbContext db, IPasswordHasher<AdminUser> hasher)
    {
        try
        {
            // 1. Clean up any admin record that previously existed in the regular users table
            var leftoverUsers = await db.Users
                .Where(u => u.Email == "admin1@taskbridge.com" || u.Phone == "admin1")
                .ToListAsync();

            if (leftoverUsers.Count > 0)
            {
                db.Users.RemoveRange(leftoverUsers);
                await db.SaveChangesAsync();
            }

            // 2. Ensure Super Admin exists in the separate dedicated 'admins' table
            var superAdmin = await db.Admins.SingleOrDefaultAsync(a =>
                a.Username == "admin1" || a.Email == "admin1@taskbridge.com");

            if (superAdmin is null)
            {
                superAdmin = new AdminUser
                {
                    Id = Guid.NewGuid(),
                    Username = "admin1",
                    FullName = "Kavindu (Super Admin)",
                    Email = "admin1@taskbridge.com",
                    Role = "SuperAdmin",
                    IsActive = true,
                    CreatedAt = DateTimeOffset.UtcNow
                };

                superAdmin.PasswordHash = hasher.HashPassword(superAdmin, "admin1");
                db.Admins.Add(superAdmin);
                await db.SaveChangesAsync();
            }
            else
            {
                bool changed = false;
                if (superAdmin.Role != "SuperAdmin")
                {
                    superAdmin.Role = "SuperAdmin";
                    changed = true;
                }
                if (!superAdmin.IsActive)
                {
                    superAdmin.IsActive = true;
                    changed = true;
                }
                var verifyResult = hasher.VerifyHashedPassword(superAdmin, superAdmin.PasswordHash, "admin1");
                if (verifyResult == PasswordVerificationResult.Failed)
                {
                    superAdmin.PasswordHash = hasher.HashPassword(superAdmin, "admin1");
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
