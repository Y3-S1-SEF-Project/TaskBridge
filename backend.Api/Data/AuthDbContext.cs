using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;

namespace TaskBridge.Api.Data;

public sealed class AuthDbContext(DbContextOptions<AuthDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<AppUser>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => x.Phone);
            entity.HasIndex(x => x.SessionToken);
            entity.Property(x => x.FullName).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(255).IsRequired();
            entity.Property(x => x.Phone).HasMaxLength(24).IsRequired();
            entity.Property(x => x.PasswordHash).IsRequired();
            entity.Property(x => x.EmailOtp).HasMaxLength(10);
        });
    }

    public async Task EnsureSchemaAsync(CancellationToken ct = default)
    {
        const string sql = @"
CREATE TABLE IF NOT EXISTS users (
    ""Id"" uuid PRIMARY KEY,
    ""FullName"" varchar(100) NOT NULL,
    ""Email"" varchar(255) NOT NULL,
    ""Phone"" varchar(24) NOT NULL,
    ""PasswordHash"" text NOT NULL,
    ""Address"" text NULL,
    ""Location"" text NULL,
    ""Preferences"" text NULL,
    ""ProfilePhotoUrl"" text NULL,
    ""EmailOtp"" varchar(10) NULL,
    ""EmailOtpExpiresAt"" timestamptz NULL,
    ""IsEmailVerified"" boolean NOT NULL DEFAULT false,
    ""SessionToken"" text NULL,
    ""FailedLogins"" integer NOT NULL DEFAULT 0,
    ""LockedUntil"" timestamptz NULL,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL,
    ""IsProvider"" boolean NOT NULL DEFAULT false,
    ""ProviderSkills"" text NULL,
    ""ProviderServices"" text NULL,
    ""ProviderExperience"" text NULL,
    ""ProviderCertifications"" text NULL,
    ""ProviderServiceAreas"" text NULL,
    ""ProviderAvailability"" text NULL,
    ""ProviderBio"" text NULL,
    ""ProviderEarnings"" numeric(12,2) NULL DEFAULT 54000.00
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS ""IsProvider"" boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderSkills"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderServices"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderExperience"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderCertifications"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderServiceAreas"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderAvailability"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderBio"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderEarnings"" numeric(12,2) NULL DEFAULT 54000.00;

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (""Email"");
CREATE INDEX IF NOT EXISTS ix_users_phone ON users (""Phone"");
CREATE INDEX IF NOT EXISTS ix_users_session_token ON users (""SessionToken"");
";
        await Database.ExecuteSqlRawAsync(sql, ct);
    }
}
