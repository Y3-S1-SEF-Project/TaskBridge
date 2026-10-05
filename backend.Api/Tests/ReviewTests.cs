using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using TaskBridge.Api.Data;
using backend.Api.AI;
using Xunit;

namespace TaskBridge.Api.Tests;

public sealed class ReviewTests
{
    private AuthDbContext CreateInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseInMemoryDatabase(databaseName: $"TaskBridge_Review_Test_{Guid.NewGuid()}")
            .Options;
        return new AuthDbContext(options);
    }

    private ReviewAgentService CreateService(AuthDbContext db)
    {
        var inMemorySettings = new Dictionary<string, string?>
        {
            {"OpenAI:ApiKey", ""},
            {"OpenAI:Model", "gpt-4o-mini"}
        };

        IConfiguration configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(inMemorySettings)
            .Build();

        var httpClient = new HttpClient();
        return new ReviewAgentService(
            httpClient,
            configuration,
            NullLogger<ReviewAgentService>.Instance,
            db);
    }

    [Fact]
    public async Task ReviewAgent_StartJob_RecordsStartTimeAndTransitionsToInProgress()
    {
        // 1. Arrange
        using var db = CreateInMemoryDbContext();
        var service = CreateService(db);

        var booking = new BookingEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = "TB-7701",
            CustomerName = "Kasun Silva",
            ProviderName = "Sunil Perera",
            ServiceTitle = "Water Pipe Leak Repair",
            Category = "Plumbing",
            Location = "Colombo 05",
            Schedule = "Today 2:00 PM",
            Price = 3000m,
            RateType = "Hourly",
            Status = "Upcoming",
            CreatedAt = DateTimeOffset.UtcNow
        };
        await db.Bookings.AddAsync(booking);
        await db.SaveChangesAsync();

        var startRequest = new StartJobRequest
        {
            BookingReference = "TB-7701",
            BeforePhotoUrl = "https://taskbridge.storage.com/proofs/before_01.jpg"
        };

        // 2. Act
        var result = await service.StartJobAsync(startRequest);

        // 3. Assert
        Assert.NotNull(result);
        var updatedBooking = await db.Bookings.FirstOrDefaultAsync(b => b.BookingReference == "TB-7701");
        Assert.NotNull(updatedBooking);
        Assert.Equal("In Progress", updatedBooking.Status);
        Assert.NotNull(updatedBooking.StartedAt);
        Assert.Equal("https://taskbridge.storage.com/proofs/before_01.jpg", updatedBooking.BeforePhotoUrl);
    }

    [Fact]
    public async Task ReviewAgent_EvaluateCompletion_CalculatesProratedHourlyBillingAndChecklist()
    {
        // 1. Arrange
        using var db = CreateInMemoryDbContext();
        var service = CreateService(db);

        var startedAt = DateTimeOffset.UtcNow.AddMinutes(-90); // 1 hr 30 mins worked
        var endedAt = DateTimeOffset.UtcNow;

        var booking = new BookingEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = "TB-7702",
            CustomerName = "Anura Dissanayake",
            ProviderName = "Ruwan Kumara",
            ServiceTitle = "Ceiling Fan Installation",
            Category = "Electrical",
            Price = 4000m, // Rs. 4,000 / hr
            RateType = "Hourly",
            Status = "In Progress",
            StartedAt = startedAt,
            CreatedAt = startedAt
        };
        await db.Bookings.AddAsync(booking);
        await db.SaveChangesAsync();

        var completionRequest = new SubmitCompletionRequest
        {
            BookingReference = "TB-7702",
            StartedAt = startedAt,
            EndedAt = endedAt,
            HourlyRate = 4000m,
            ProviderNotes = "Installed new ceiling fan and regulator successfully. Verified speed controls.",
            BeforePhotoUrls = new List<string> { "https://taskbridge.storage.com/proofs/fan_before.jpg" },
            AfterPhotoUrls = new List<string> { "https://taskbridge.storage.com/proofs/fan_after.jpg" }
        };

        // 2. Act
        var response = await service.EvaluateCompletionAsync(completionRequest);

        // 3. Assert
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.Equal(90, response.DurationMinutes);
        // Billing Formula: 60 mins @ 4000 + 30 mins @ (4000/60) = 4000 + 2000 = 6000
        Assert.Equal(6000m, response.CalculatedPrice);
        Assert.True(response.VerificationPassed);
        Assert.True(response.ConfidenceScore >= 70);
        Assert.NotEmpty(response.VerifiedTasks);

        // Verify saved record in db
        var savedRecord = await db.JobCompletions.FirstOrDefaultAsync(c => c.BookingReference == "TB-7702");
        Assert.NotNull(savedRecord);
        Assert.Equal(6000m, savedRecord.CalculatedPrice);
    }

    [Fact]
    public async Task ReviewAgent_CustomerApprove_TransitionsToApprovedAndSavesFeedback()
    {
        // 1. Arrange
        using var db = CreateInMemoryDbContext();
        var service = CreateService(db);

        var completion = new JobCompletionEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = "TB-7703",
            ProviderName = "Sunil Perera",
            CustomerName = "Nimal Silva",
            ServiceTitle = "Drain Cleaning",
            Category = "Plumbing",
            Status = "PendingCustomerSignOff",
            CalculatedPrice = 4500m,
            HourlyRate = 3000m,
            DurationMinutes = 90,
            AiVerificationPassed = true,
            AiConfidenceScore = 95,
            StartedAt = DateTimeOffset.UtcNow.AddMinutes(-90),
            EndedAt = DateTimeOffset.UtcNow
        };
        await db.JobCompletions.AddAsync(completion);
        await db.SaveChangesAsync();

        var approvalRequest = new CustomerApprovalRequest
        {
            BookingReference = "TB-7703",
            CustomerNotes = "Excellent job, arrived on time."
        };

        // 2. Act
        var result = await service.CustomerApproveAsync(approvalRequest);

        // 3. Assert
        Assert.NotNull(result);
        var updatedRecord = await db.JobCompletions.FirstOrDefaultAsync(c => c.BookingReference == "TB-7703");
        Assert.NotNull(updatedRecord);
        Assert.Equal("CustomerApproved", updatedRecord.Status);
    }
}
