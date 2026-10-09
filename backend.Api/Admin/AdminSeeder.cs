using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;
using backend.Api.AI;

namespace TaskBridge.Api.Admin;

public static class AdminSeeder
{
    public static async Task SeedSuperAdminAsync(AuthDbContext db, IPasswordHasher<AdminUser> hasher)
    {
        // Ensure verification columns exist on PostgreSQL providers and users tables FIRST
        await EnsureVerificationSchemaAsync(db);

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

            // 3. Ensure verification columns exist on PostgreSQL providers and users tables
            await EnsureVerificationSchemaAsync(db);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AdminSeeder] Notice: {ex.Message}");
        }
    }

    public static async Task EnsureVerificationSchemaAsync(AuthDbContext db)
    {
        try
        {
            await db.Database.ExecuteSqlRawAsync(@"
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""IsVerified"" boolean NOT NULL DEFAULT false;
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationDocumentUrl"" text;
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationDocumentType"" text;
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationStatus"" character varying(32) NOT NULL DEFAULT 'Unverified';
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationSubmittedAt"" timestamp with time zone;
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationApprovedAt"" timestamp with time zone;
                ALTER TABLE providers ADD COLUMN IF NOT EXISTS ""VerificationNotes"" text;

                ALTER TABLE users ADD COLUMN IF NOT EXISTS ""IsVerifiedProvider"" boolean NOT NULL DEFAULT false;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderVerificationDocumentUrl"" text;
                ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderVerificationStatus"" character varying(32) NOT NULL DEFAULT 'Unverified';
            ");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AdminSeeder] Schema verify notice: {ex.Message}");
        }
    }
}

