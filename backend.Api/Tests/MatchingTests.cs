using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using TaskBridge.Api.Data;
using backend.Api.AI;
using Xunit;

namespace TaskBridge.Api.Tests;

public class MatchingTests
{
    private AuthDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: $"TaskBridge_Matching_Test_{Guid.NewGuid()}")
            .Options;
        return new AuthDbContext(options);
    }

    [Fact]
    public async Task MatchingAgent_SavesJobMatchAudit_AndUpdatesServiceRequestStatus()
    {
        // 1. Arrange In-Memory Database
        using var db = CreateInMemoryDbContext();
        var customerId = Guid.NewGuid();
        var requestId = Guid.NewGuid();

        // Seed a sample service request
        var serviceRequest = new ServiceRequestEntity
        {
            Id = requestId,
            CustomerId = customerId,
            CustomerName = "Nimal Silva",
            CustomerPhone = "+94771234567",
            Title = "Garden Cleanup & Grass Trimming",
            Category = "Gardening",
            Description = "Need lawn mowing and yard cleaning",
            Location = "Colombo 05",
            Status = "Pending",
            CreatedAt = DateTimeOffset.UtcNow
        };
        await db.ServiceRequests.AddAsync(serviceRequest);

        // Seed active provider
        var providerUser = new TaskBridge.Api.Auth.AppUser
        {
            Id = Guid.NewGuid(),
            FullName = "Kamal Perera",
            Email = "kamal@taskbridge.com",
            Phone = "+94779876543",
            PasswordHash = "hash"
        };
        await db.Users.AddAsync(providerUser);

        var provider = new TaskBridge.Api.Auth.ProviderProfile
        {
            Id = Guid.NewGuid(),
            UserId = providerUser.Id,
            Category = "Gardening",
            Skills = "Lawn mowing, yard clearing, landscaping",
            ServiceAreas = "Colombo 05, Colombo 03",
            HourlyRate = 2200m,
            Rating = 4.9,
            ReviewCount = 18,
            IsActive = true
        };
        await db.Providers.AddAsync(provider);
        await db.SaveChangesAsync();

        // Setup MatchingAgentService
        var config = new ConfigurationBuilder().Build();
        var httpClient = new HttpClient();
        var service = new MatchingAgentService(db, httpClient, config, NullLogger<MatchingAgentService>.Instance);

        var matchingRequest = new MatchingRequest
        {
            ServiceRequestId = requestId.ToString(),
            CustomerUserId = customerId.ToString(),
            CustomerName = "Nimal Silva",
            JobPlan = new JobPlanDetails
            {
                ServiceTitle = "Garden Cleanup & Grass Trimming",
                Category = "Gardening",
                Location = "Colombo 05",
                Budget = 4000m
            }
        };

        // 2. Act
        var response = await service.MatchProvidersAsync(matchingRequest);

        // 3. Assert Response
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.NotNull(response.MatchAuditId);
        Assert.NotEmpty(response.MatchedProviders);

        // Assert Option 1: JobMatchEntity saved in database
        var savedAudit = await db.JobMatches.FirstOrDefaultAsync(m => m.Id == response.MatchAuditId.Value);
        Assert.NotNull(savedAudit);
        Assert.Equal("Gardening", savedAudit.Category);
        Assert.Equal(customerId, savedAudit.CustomerUserId);
        Assert.Equal(requestId, savedAudit.ServiceRequestId);
        Assert.NotEmpty(savedAudit.MatchesJson);

        // Assert Option 2: ServiceRequestEntity updated to "Matched"
        var updatedRequest = await db.ServiceRequests.FirstOrDefaultAsync(r => r.Id == requestId);
        Assert.NotNull(updatedRequest);
        Assert.Equal("Matched", updatedRequest.Status);
        Assert.False(string.IsNullOrWhiteSpace(updatedRequest.MatchedProvidersJson));
        Assert.NotNull(updatedRequest.UpdatedAt);
    }

    [Fact]
    public async Task MatchingAgent_FiltersInactiveProviders()
    {
        // TC-AI-MATCH-02: Inactive provider exclusion (Bug fix verification)
        using var db = CreateInMemoryDbContext();
        var customerId = Guid.NewGuid();
        var requestId = Guid.NewGuid();

        // Seed inactive provider
        var inactiveUser = new TaskBridge.Api.Auth.AppUser
        {
            Id = Guid.NewGuid(),
            FullName = "Inactive Electrician",
            Email = "inactive@taskbridge.com",
            Phone = "+94770000001",
            PasswordHash = "hash"
        };
        await db.Users.AddAsync(inactiveUser);

        var inactiveProvider = new TaskBridge.Api.Auth.ProviderProfile
        {
            Id = Guid.NewGuid(),
            UserId = inactiveUser.Id,
            Category = "Electrical",
            Skills = "Wiring",
            ServiceAreas = "Colombo",
            HourlyRate = 2000m,
            Rating = 5.0,
            ReviewCount = 10,
            IsActive = false // INACTIVE
        };
        await db.Providers.AddAsync(inactiveProvider);
        await db.SaveChangesAsync();

        var config = new ConfigurationBuilder().Build();
        var service = new MatchingAgentService(db, new HttpClient(), config, NullLogger<MatchingAgentService>.Instance);

        var matchingRequest = new MatchingRequest
        {
            ServiceRequestId = requestId.ToString(),
            CustomerUserId = customerId.ToString(),
            CustomerName = "Test Customer",
            JobPlan = new JobPlanDetails
            {
                ServiceTitle = "Wiring fix",
                Category = "Electrical",
                Location = "Colombo",
                Budget = 3000m
            }
        };

        var response = await service.MatchProvidersAsync(matchingRequest);
        Assert.NotNull(response);
        Assert.DoesNotContain(response.MatchedProviders, p => p.ProviderId == inactiveProvider.Id);
    }

    [Fact]
    public async Task MatchingAgent_ConformsToOutputSchema()
    {
        // TC-AI-SCH-02: Matching Output Schema
        using var db = CreateInMemoryDbContext();
        var config = new ConfigurationBuilder().Build();
        var service = new MatchingAgentService(db, new HttpClient(), config, NullLogger<MatchingAgentService>.Instance);

        var response = await service.MatchProvidersAsync(new MatchingRequest
        {
            ServiceRequestId = Guid.NewGuid().ToString(),
            CustomerUserId = Guid.NewGuid().ToString(),
            CustomerName = "Schema Test",
            JobPlan = new JobPlanDetails { ServiceTitle = "Fan Repair", Category = "Electrical", Location = "Colombo" }
        });

        Assert.NotNull(response);
        Assert.NotNull(response.MatchedProviders);
        Assert.True(response.Success);
    }
}
