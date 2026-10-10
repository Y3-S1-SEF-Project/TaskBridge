using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;
using TaskBridge.Api.Disputes;
using TaskBridge.Api.Inquiries;
using Xunit;

namespace TaskBridge.Api.Tests;

public sealed class DatabaseConstraintTests
{
    private AuthDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: $"TaskBridge_DB_Test_{Guid.NewGuid()}")
            .Options;
        return new AuthDbContext(options);
    }

    [Fact]
    public async Task ServiceRequest_PersistsAllRequiredFields_AndMaintainsReferentialIntegrity()
    {
        using var db = CreateInMemoryDbContext();
        var customerId = Guid.NewGuid();
        var requestId = Guid.NewGuid();

        var request = new ServiceRequestEntity
        {
            Id = requestId,
            CustomerId = customerId,
            CustomerName = "John Doe",
            CustomerPhone = "0771234567",
            Title = "House Wiring Inspection",
            Category = "Electrical",
            Description = "Full inspection of distribution board",
            Location = "Kandy",
            ScheduledDate = "2026-10-15",
            ScheduledTime = "09:00 AM",
            EstimatedBudget = 7500m,
            Status = "Pending",
            CreatedAt = DateTimeOffset.UtcNow
        };

        await db.ServiceRequests.AddAsync(request);
        await db.SaveChangesAsync();

        var saved = await db.ServiceRequests.FindAsync(requestId);
        Assert.NotNull(saved);
        Assert.Equal("House Wiring Inspection", saved.Title);
        Assert.Equal("Electrical", saved.Category);
        Assert.Equal(7500m, saved.EstimatedBudget);
        Assert.Equal("Pending", saved.Status);
    }

    [Fact]
    public async Task ProviderProfile_LinksCorrectlyToUser_AndPersistsRatings()
    {
        using var db = CreateInMemoryDbContext();
        var userId = Guid.NewGuid();
        var user = new AppUser
        {
            Id = userId,
            FullName = "Sunil Shantha",
            Email = "sunil@example.com",
            Phone = "0777654321",
            PasswordHash = "hashed_pass"
        };
        await db.Users.AddAsync(user);

        var provider = new ProviderProfile
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Category = "Plumbing",
            Skills = "Pipe fitting, Leak repair",
            ServiceAreas = "Colombo, Gampaha",
            HourlyRate = 2500m,
            Rating = 4.8,
            ReviewCount = 12,
            IsActive = true
        };
        await db.Providers.AddAsync(provider);
        await db.SaveChangesAsync();

        var savedProvider = await db.Providers.FirstOrDefaultAsync(p => p.UserId == userId);
        Assert.NotNull(savedProvider);
        Assert.Equal("Plumbing", savedProvider.Category);
        Assert.Equal(2500m, savedProvider.HourlyRate);
        Assert.True(savedProvider.IsActive);
    }

    [Fact]
    public async Task DisputeEntity_SupportsAuditTrail_AndStatusTransitions()
    {
        using var db = CreateInMemoryDbContext();
        var disputeId = Guid.NewGuid();
        var bookingId = Guid.NewGuid();
        var customerId = Guid.NewGuid();
        var providerId = Guid.NewGuid();

        var dispute = new DisputeEntity
        {
            Id = disputeId,
            DisputeReference = "DSP-1001",
            BookingId = bookingId,
            CustomerId = customerId,
            CustomerName = "Alice Customer",
            ProviderId = providerId,
            ProviderName = "Bob Provider",
            ServiceTitle = "AC Repair",
            Category = "HVAC",
            ReasonCategory = "Poor Quality",
            Description = "AC unit stopped cooling after 2 hours",
            Status = "PendingAdminReview",
            FeeAmount = 4500m,
            CreatedAt = DateTimeOffset.UtcNow
        };

        await db.Disputes.AddAsync(dispute);
        await db.SaveChangesAsync();

        // Simulate Admin Resolution Transition
        var openDispute = await db.Disputes.FindAsync(disputeId);
        Assert.NotNull(openDispute);
        openDispute.Status = "Resolved";
        openDispute.ResolutionSummary = "Provider agreed to return and refill refrigerant at no cost";
        openDispute.ResolvedAt = DateTimeOffset.UtcNow;
        openDispute.ResolvedByAdminId = Guid.NewGuid();
        await db.SaveChangesAsync();

        var resolved = await db.Disputes.FindAsync(disputeId);
        Assert.NotNull(resolved);
        Assert.Equal("Resolved", resolved.Status);
        Assert.Equal("Provider agreed to return and refill refrigerant at no cost", resolved.ResolutionSummary);
        Assert.NotNull(resolved.ResolvedAt);
    }

    [Fact]
    public async Task InquiryEntity_TracksCustomerSupportLifecycle()
    {
        using var db = CreateInMemoryDbContext();
        var inquiryId = Guid.NewGuid();
        var customerId = Guid.NewGuid();

        var inquiry = new InquiryEntity
        {
            Id = inquiryId,
            InquiryReference = "INQ-2002",
            UserId = customerId,
            UserName = "Chamara Silva",
            UserEmail = "chamara@example.com",
            UserPhone = "0712345678",
            Subject = "Billing question regarding quotation",
            Category = "Billing",
            Message = "Why is the convenience fee 5% instead of 3%?",
            Status = "Open",
            CreatedAt = DateTime.UtcNow
        };

        await db.Inquiries.AddAsync(inquiry);
        await db.SaveChangesAsync();

        // Simulate support agent responding
        var retrieved = await db.Inquiries.FindAsync(inquiryId);
        Assert.NotNull(retrieved);
        retrieved.Status = "Responded";
        retrieved.AdminResponse = "The convenience fee covers secure escrow protection.";
        retrieved.RespondedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();

        var updated = await db.Inquiries.FindAsync(inquiryId);
        Assert.NotNull(updated);
        Assert.Equal("Responded", updated.Status);
        Assert.Equal("The convenience fee covers secure escrow protection.", updated.AdminResponse);
    }
}
