using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using backend.Api.AI;

namespace TaskBridge.Api.Data;

public sealed class AuthDbContext(DbContextOptions<AuthDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<ProviderProfile> Providers => Set<ProviderProfile>();
    public DbSet<BookingEntity> Bookings => Set<BookingEntity>();
    public DbSet<ProposalEntity> Proposals => Set<ProposalEntity>();
    public DbSet<JobCompletionEntity> JobCompletions => Set<JobCompletionEntity>();
    public DbSet<FeedbackEntity> Feedbacks => Set<FeedbackEntity>();
    public DbSet<ChatConversation> ChatConversations => Set<ChatConversation>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ChatAuditLog> ChatAuditLogs => Set<ChatAuditLog>();

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
    }
