using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Admin;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Notifications;
using backend.Api.AI;

namespace TaskBridge.Api.Data;

public sealed class AuthDbContext(DbContextOptions<AuthDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<AdminUser> Admins => Set<AdminUser>();
    public DbSet<ProviderProfile> Providers => Set<ProviderProfile>();
    public DbSet<BookingEntity> Bookings => Set<BookingEntity>();
    public DbSet<ProposalEntity> Proposals => Set<ProposalEntity>();
    public DbSet<JobCompletionEntity> JobCompletions => Set<JobCompletionEntity>();
    public DbSet<FeedbackEntity> Feedbacks => Set<FeedbackEntity>();
    public DbSet<ServiceRequestEntity> ServiceRequests => Set<ServiceRequestEntity>();
    public DbSet<ChatConversation> ChatConversations => Set<ChatConversation>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ChatAuditLog> ChatAuditLogs => Set<ChatAuditLog>();
    public DbSet<NotificationEntity> Notifications => Set<NotificationEntity>();

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
            entity.Property(x => x.Role).HasMaxLength(32).HasDefaultValue("User");
            entity.HasIndex(x => x.Role);
        });

        model.Entity<AdminUser>(entity =>
        {
            entity.ToTable("admins");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Username).IsUnique();
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => x.SessionToken);
            entity.Property(x => x.Username).HasMaxLength(50).IsRequired();
            entity.Property(x => x.FullName).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(255).IsRequired();
            entity.Property(x => x.PasswordHash).IsRequired();
            entity.Property(x => x.Role).HasMaxLength(32).HasDefaultValue("Admin");
            entity.Property(x => x.IsActive).HasDefaultValue(true);
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

        model.Entity<ServiceRequestEntity>(entity =>
        {
            entity.ToTable("service_requests");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.CustomerId);
            entity.HasIndex(x => x.Status);
            entity.HasIndex(x => x.Category);
            entity.Property(x => x.Title).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(100).IsRequired();
            entity.Property(x => x.EstimatedBudget).HasColumnType("numeric(12,2)");
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

        model.Entity<JobCompletionEntity>(entity =>
        {
            entity.ToTable("job_completions");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.BookingReference);
            entity.HasIndex(x => x.ProviderId);
            entity.HasIndex(x => x.Status);
            entity.Property(x => x.HourlyRate).HasColumnType("numeric(12,2)");
            entity.Property(x => x.CalculatedPrice).HasColumnType("numeric(12,2)");
        });

        model.Entity<FeedbackEntity>(entity =>
        {
            entity.ToTable("feedbacks");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.BookingReference);
            entity.HasIndex(x => x.ProviderId);
            entity.HasIndex(x => x.CustomerId);
        });

        model.Entity<NotificationEntity>(entity =>
        {
            entity.ToTable("notifications");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => x.UserName);
            entity.HasIndex(x => x.IsRead);
            entity.HasIndex(x => x.CreatedAt);
            entity.Property(x => x.Title).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Type).HasMaxLength(50).IsRequired();
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
ALTER TABLE users ADD COLUMN IF NOT EXISTS ""Role"" text NOT NULL DEFAULT 'User';

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (""Email"");
CREATE INDEX IF NOT EXISTS ix_users_phone ON users (""Phone"");
CREATE INDEX IF NOT EXISTS ix_users_session_token ON users (""SessionToken"");
CREATE INDEX IF NOT EXISTS ix_users_role ON users (""Role"");

-- Separate Dedicated Admins Table
CREATE TABLE IF NOT EXISTS admins (
    ""Id"" uuid PRIMARY KEY,
    ""Username"" text NOT NULL,
    ""FullName"" text NOT NULL,
    ""Email"" text NOT NULL,
    ""PasswordHash"" text NOT NULL,
    ""Role"" text NOT NULL DEFAULT 'Admin',
    ""SessionToken"" text NULL,
    ""IsActive"" boolean NOT NULL DEFAULT true,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_admins_username ON admins (""Username"");
CREATE UNIQUE INDEX IF NOT EXISTS ix_admins_email ON admins (""Email"");
CREATE INDEX IF NOT EXISTS ix_admins_session_token ON admins (""SessionToken"");

-- Clean up any admin credentials that were temporarily placed in users table
DELETE FROM users WHERE ""Email"" = 'admin1@taskbridge.com' OR ""Phone"" = 'admin1';

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
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""RateType"" text NOT NULL DEFAULT 'Hourly';
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS ""RateType"" text NOT NULL DEFAULT 'Hourly';
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""Notes"" text NULL;
ALTER TABLE proposals ADD COLUMN IF NOT EXISTS ""Notes"" text NULL;

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
    ""RateType"" text NOT NULL DEFAULT 'Hourly',
    ""Status"" text NOT NULL DEFAULT 'Pending',
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

CREATE INDEX IF NOT EXISTS ix_proposals_reference ON proposals (""ProposalReference"");
CREATE INDEX IF NOT EXISTS ix_proposals_status ON proposals (""Status"");
CREATE INDEX IF NOT EXISTS ix_proposals_provider_id ON proposals (""ProviderId"");

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""StartedAt"" timestamptz NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""EndedAt"" timestamptz NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""DurationMinutes"" integer NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""FinalCalculatedPrice"" numeric(12,2) NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""BeforePhotoUrl"" text NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS ""AgreedChecklist"" text NULL;

CREATE TABLE IF NOT EXISTS job_completions (
    ""Id"" uuid PRIMARY KEY,
    ""BookingReference"" text NOT NULL,
    ""BookingId"" uuid NULL,
    ""ProviderId"" uuid NULL,
    ""ProviderName"" text NOT NULL DEFAULT '',
    ""CustomerId"" uuid NULL,
    ""CustomerName"" text NOT NULL DEFAULT 'Customer',
    ""ServiceTitle"" text NOT NULL DEFAULT '',
    ""Category"" text NOT NULL DEFAULT '',
    ""ProviderNotes"" text NOT NULL DEFAULT '',
    ""BeforePhotoUrl"" text NULL,
    ""AfterPhotoUrls"" text NOT NULL DEFAULT '[]',
    ""StartedAt"" timestamptz NOT NULL DEFAULT now(),
    ""EndedAt"" timestamptz NOT NULL DEFAULT now(),
    ""DurationMinutes"" integer NOT NULL DEFAULT 0,
    ""HourlyRate"" numeric(12,2) NOT NULL DEFAULT 0,
    ""CalculatedPrice"" numeric(12,2) NOT NULL DEFAULT 0,
    ""AiVerificationPassed"" boolean NOT NULL DEFAULT false,
    ""AiConfidenceScore"" integer NOT NULL DEFAULT 0,
    ""AiComparisonAnalysis"" text NOT NULL DEFAULT '',
    ""AiVerifiedTasks"" text NOT NULL DEFAULT '[]',
    ""AiMissingDetails"" text NOT NULL DEFAULT '[]',
    ""Status"" text NOT NULL DEFAULT 'PendingAiReview',
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

CREATE INDEX IF NOT EXISTS ix_completions_booking_ref ON job_completions (""BookingReference"");
CREATE INDEX IF NOT EXISTS ix_completions_provider_id ON job_completions (""ProviderId"");
CREATE INDEX IF NOT EXISTS ix_completions_status ON job_completions (""Status"");

CREATE TABLE IF NOT EXISTS feedbacks (
    ""Id"" uuid PRIMARY KEY,
    ""BookingReference"" text NOT NULL,
    ""CustomerId"" uuid NULL,
    ""CustomerName"" text NOT NULL DEFAULT 'Customer',
    ""ProviderId"" uuid NULL,
    ""ProviderName"" text NOT NULL DEFAULT '',
    ""Rating"" integer NOT NULL DEFAULT 5,
    ""Comment"" text NOT NULL DEFAULT '',
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_feedbacks_booking_ref ON feedbacks (""BookingReference"");
CREATE INDEX IF NOT EXISTS ix_feedbacks_provider_id ON feedbacks (""ProviderId"");
CREATE INDEX IF NOT EXISTS ix_feedbacks_customer_id ON feedbacks (""CustomerId"");

CREATE TABLE IF NOT EXISTS chat_conversations (
    ""Id"" uuid PRIMARY KEY,
    ""BookingReference"" text NULL,
    ""CustomerId"" uuid NOT NULL,
    ""CustomerName"" varchar(150) NOT NULL,
    ""ProviderId"" uuid NOT NULL,
    ""ProviderName"" varchar(150) NOT NULL,
    ""LastMessageAt"" timestamptz NOT NULL DEFAULT now(),
    ""LastMessageSnippet"" text NULL,
    ""UnreadCustomer"" integer NOT NULL DEFAULT 0,
    ""UnreadProvider"" integer NOT NULL DEFAULT 0,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_chat_conv_customer ON chat_conversations (""CustomerId"");
CREATE INDEX IF NOT EXISTS ix_chat_conv_provider ON chat_conversations (""ProviderId"");
CREATE INDEX IF NOT EXISTS ix_chat_conv_booking ON chat_conversations (""BookingReference"");

CREATE TABLE IF NOT EXISTS chat_messages (
    ""Id"" uuid PRIMARY KEY,
    ""ConversationId"" uuid NOT NULL REFERENCES chat_conversations (""Id"") ON DELETE CASCADE,
    ""SenderId"" uuid NOT NULL,
    ""SenderName"" varchar(150) NOT NULL,
    ""RecipientId"" uuid NOT NULL,
    ""MessageType"" varchar(20) NOT NULL DEFAULT 'Text',
    ""EncryptedContent"" text NOT NULL,
    ""MediaUrl"" text NULL,
    ""IsRead"" boolean NOT NULL DEFAULT false,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_chat_messages_conv ON chat_messages (""ConversationId"");
CREATE INDEX IF NOT EXISTS ix_chat_messages_created ON chat_messages (""CreatedAt"");

CREATE TABLE IF NOT EXISTS chat_audit_logs (
    ""Id"" uuid PRIMARY KEY,
    ""AdminId"" uuid NOT NULL,
    ""AdminName"" varchar(150) NOT NULL,
    ""ConversationId"" uuid NOT NULL,
    ""Reason"" varchar(500) NOT NULL,
    ""AccessedAt"" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_chat_audit_conv ON chat_audit_logs (""ConversationId"");

CREATE TABLE IF NOT EXISTS service_requests (
    ""Id"" uuid PRIMARY KEY,
    ""CustomerId"" uuid NOT NULL,
    ""CustomerName"" varchar(150) NOT NULL,
    ""CustomerPhone"" varchar(30) NOT NULL,
    ""Title"" varchar(200) NOT NULL,
    ""Category"" varchar(100) NOT NULL,
    ""Description"" text NOT NULL,
    ""Location"" text NOT NULL,
    ""LocationAddress"" text NULL,
    ""EstimatedBudget"" numeric(12,2) NULL,
    ""ScheduledDate"" text NOT NULL,
    ""ScheduledTime"" text NOT NULL,
    ""Status"" varchar(50) NOT NULL DEFAULT 'ClarificationRequired',
    ""MediaUrlsJson"" text NULL,
    ""AiPlanJson"" text NULL,
    ""ClarificationAnswersJson"" text NULL,
    ""CancellationReason"" text NULL,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now(),
    ""UpdatedAt"" timestamptz NULL
);

CREATE INDEX IF NOT EXISTS ix_service_requests_customer ON service_requests (""CustomerId"");
CREATE INDEX IF NOT EXISTS ix_service_requests_status ON service_requests (""Status"");
CREATE INDEX IF NOT EXISTS ix_service_requests_category ON service_requests (""Category"");

CREATE TABLE IF NOT EXISTS notifications (
    ""Id"" uuid PRIMARY KEY,
    ""UserId"" uuid NULL,
    ""UserName"" varchar(150) NULL,
    ""Title"" varchar(200) NOT NULL,
    ""Message"" text NOT NULL,
    ""Type"" varchar(50) NOT NULL DEFAULT 'General',
    ""ReferenceId"" varchar(100) NULL,
    ""ReferenceType"" varchar(50) NULL,
    ""MetadataJson"" text NULL,
    ""IsRead"" boolean NOT NULL DEFAULT false,
    ""CreatedAt"" timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications (""UserId"");
CREATE INDEX IF NOT EXISTS ix_notifications_user_name ON notifications (""UserName"");
CREATE INDEX IF NOT EXISTS ix_notifications_is_read ON notifications (""IsRead"");
CREATE INDEX IF NOT EXISTS ix_notifications_created_at ON notifications (""CreatedAt"");
";
        await Database.ExecuteSqlRawAsync(sql, ct);
    }
}
