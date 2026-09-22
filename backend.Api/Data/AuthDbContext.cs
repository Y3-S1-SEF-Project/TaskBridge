using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;

namespace TaskBridge.Api.Data;

public sealed class AuthDbContext(DbContextOptions<AuthDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<ProviderProfile> Providers => Set<ProviderProfile>();
    public DbSet<BookingEntity> Bookings => Set<BookingEntity>();
    public DbSet<ProposalEntity> Proposals => Set<ProposalEntity>();

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

        model.Entity<ProviderProfile>(entity =>
        {
            entity.ToTable("providers");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.UserId).IsUnique();
            entity.HasIndex(x => x.Category);
            entity.HasIndex(x => x.IsActive);
            entity.Property(x => x.Category).IsRequired();
            entity.Property(x => x.HourlyRate).HasColumnType("numeric(12,2)").HasDefaultValue(2500.00m);
            entity.Property(x => x.Rating).HasDefaultValue(4.8);
            entity.Property(x => x.ReviewCount).HasDefaultValue(12);
            entity.Property(x => x.IsActive).HasDefaultValue(true);

            entity.HasOne(x => x.User)
                  .WithOne(x => x.ProviderProfile)
                  .HasForeignKey<ProviderProfile>(x => x.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        model.Entity<BookingEntity>(entity =>
        {
            entity.ToTable("bookings");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.BookingReference);
            entity.HasIndex(x => x.Status);
            entity.HasIndex(x => x.ProviderId);
            entity.Property(x => x.Price).HasColumnType("numeric(12,2)");
        });

        model.Entity<ProposalEntity>(entity =>
        {
            entity.ToTable("proposals");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.ProposalReference);
            entity.HasIndex(x => x.Status);
            entity.HasIndex(x => x.ProviderId);
            entity.Property(x => x.EstimatedRate).HasColumnType("numeric(12,2)");
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
    ""ProviderCategory"" text NULL,
    ""ProviderSkills"" text NULL,
    ""ProviderServices"" text NULL,
    ""ProviderExperience"" text NULL,
    ""ProviderCertifications"" text NULL,
    ""ProviderServiceAreas"" text NULL,
    ""ProviderAvailability"" text NULL,
    ""ProviderBio"" text NULL,
    ""ProviderEarnings"" numeric(12,2) NULL DEFAULT 54000.00,
    ""ProviderHourlyRate"" numeric(12,2) NULL DEFAULT 2500.00
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS ""IsProvider"" boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderCategory"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderSkills"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderServices"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderExperience"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderCertifications"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderServiceAreas"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderAvailability"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderBio"" text NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderEarnings"" numeric(12,2) NULL DEFAULT 54000.00;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""ProviderHourlyRate"" numeric(12,2) NULL DEFAULT 2500.00;

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (""Email"");
CREATE INDEX IF NOT EXISTS ix_users_phone ON users (""Phone"");
CREATE INDEX IF NOT EXISTS ix_users_session_token ON users (""SessionToken"");

CREATE TABLE IF NOT EXISTS providers (
    ""Id"" uuid PRIMARY KEY,
    ""UserId"" uuid NOT NULL UNIQUE,
    ""Category"" text NOT NULL DEFAULT 'General',
    ""Skills"" text NULL,
    ""Services"" text NULL,
    ""Experience"" text NULL,
    ""Certifications"" text NULL,
    ""ServiceAreas"" text NULL,
    ""Availability"" text NULL,
    ""HourlyRate"" numeric(12,2) NOT NULL DEFAULT 2500.00,
    ""Rating"" double precision NOT NULL DEFAULT 4.8,
    ""ReviewCount"" integer NOT NULL DEFAULT 12,
    ""IsActive"" boolean NOT NULL DEFAULT true,
    ""Bio"" text NULL,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL,
    CONSTRAINT fk_providers_user FOREIGN KEY (""UserId"") REFERENCES users (""Id"") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_providers_user_id ON providers (""UserId"");
CREATE INDEX IF NOT EXISTS ix_providers_category ON providers (""Category"");
CREATE INDEX IF NOT EXISTS ix_providers_is_active ON providers (""IsActive"");

-- Automatically migrate all existing registered providers from users table into providers table
INSERT INTO providers (""Id"" , ""UserId"", ""Category"", ""Skills"", ""Services"", ""Experience"", ""Certifications"", ""ServiceAreas"", ""Availability"", ""Bio"", ""CreatedAt"")
SELECT 
    gen_random_uuid(),
    u.""Id"",
    COALESCE(NULLIF(TRIM(u.""ProviderServices""), ''), NULLIF(TRIM(u.""ProviderSkills""), ''), 'General'),
    u.""ProviderSkills"",
    u.""ProviderServices"",
    u.""ProviderExperience"",
    u.""ProviderCertifications"",
    COALESCE(NULLIF(TRIM(u.""ProviderServiceAreas""), ''), NULLIF(TRIM(u.""Location""), ''), 'Colombo'),
    u.""ProviderAvailability"",
    u.""ProviderBio"",
    u.""CreatedAt""
FROM users u
WHERE u.""IsProvider"" = true
  AND NOT EXISTS (SELECT 1 FROM providers p WHERE p.""UserId"" = u.""Id"");

CREATE TABLE IF NOT EXISTS bookings (
    ""Id"" uuid PRIMARY KEY,
    ""BookingReference"" text NOT NULL,
    ""ProposalId"" uuid NULL,
    ""CustomerId"" uuid NULL,
    ""CustomerName"" text NOT NULL DEFAULT 'Customer',
    ""ProviderId"" uuid NULL,
    ""ProviderName"" text NOT NULL DEFAULT '',
    ""ServiceTitle"" text NOT NULL,
    ""Category"" text NOT NULL,
    ""Location"" text NOT NULL,
    ""Schedule"" text NOT NULL,
    ""Price"" numeric(12,2) NOT NULL,
    ""Status"" text NOT NULL DEFAULT 'Upcoming',
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""ProposalId"" uuid NULL;

CREATE INDEX IF NOT EXISTS ix_bookings_reference ON bookings (""BookingReference"");
CREATE INDEX IF NOT EXISTS ix_bookings_status ON bookings (""Status"");

CREATE TABLE IF NOT EXISTS proposals (
    ""Id"" uuid PRIMARY KEY,
    ""ProposalReference"" text NOT NULL,
    ""CustomerId"" uuid NULL,
    ""CustomerName"" text NOT NULL DEFAULT 'Customer',
    ""ProviderId"" uuid NULL,
    ""ProviderName"" text NOT NULL DEFAULT '',
    ""ServiceTitle"" text NOT NULL,
    ""Category"" text NOT NULL,
    ""Location"" text NOT NULL,
    ""PreferredSchedule"" text NOT NULL,
    ""EstimatedRate"" numeric(12,2) NOT NULL,
    ""Status"" text NOT NULL DEFAULT 'Pending',
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

CREATE INDEX IF NOT EXISTS ix_proposals_reference ON proposals (""ProposalReference"");
CREATE INDEX IF NOT EXISTS ix_proposals_status ON proposals (""Status"");
CREATE INDEX IF NOT EXISTS ix_proposals_provider_id ON proposals (""ProviderId"");
";
        await Database.ExecuteSqlRawAsync(sql, ct);
    }
}
