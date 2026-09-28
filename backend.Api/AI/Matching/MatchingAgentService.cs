using System.Diagnostics;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace backend.Api.AI;

public class MatchingAgentService
{
    private readonly AuthDbContext _dbContext;
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<MatchingAgentService> _logger;

    public MatchingAgentService(
        AuthDbContext dbContext,
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<MatchingAgentService> logger)
    {
        _dbContext = dbContext;
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<MatchingResponse> MatchProvidersAsync(MatchingRequest request, CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        var job = request.JobPlan;
        var requestedCategory = string.IsNullOrWhiteSpace(job.Category) ? "Plumbing" : job.Category;
        var requestedLocation = string.IsNullOrWhiteSpace(job.Location) ? "Colombo 05" : job.Location;

        Console.ForegroundColor = ConsoleColor.Magenta;
        Console.WriteLine("\n============================================================");
        Console.WriteLine($"[🤖 TASKBRIDGE AI: AGENT 2 - MATCHING AGENT]");
        Console.WriteLine($"📋 Received Plan from Agent 1: \"{job.ServiceTitle}\" ({requestedCategory})");
        Console.WriteLine($"📍 Customer Location: {requestedLocation} | Budget: {job.BudgetDisplay}");
        Console.WriteLine("============================================================\n");
        Console.ResetColor();

        // 1. Fetch active providers from database
        var dbProviders = await _dbContext.Providers
            .Include(p => p.User)
            .Where(p => p.IsActive)
            .ToListAsync(ct);

        // Exclude the current customer's own provider profile so they never match with themselves
        if (!string.IsNullOrWhiteSpace(request.CustomerUserId) && Guid.TryParse(request.CustomerUserId, out var custGuid))
        {
            dbProviders = dbProviders.Where(p => p.UserId != custGuid).ToList();
        }
        if (!string.IsNullOrWhiteSpace(request.CustomerName))
        {
            var custName = request.CustomerName.Trim().ToLowerInvariant();
            dbProviders = dbProviders.Where(p => p.User == null || p.User.FullName.Trim().ToLowerInvariant() != custName).ToList();
        }

        var candidatePool = new List<MatchedProviderDto>();

        foreach (var p in dbProviders)
        {
            var user = p.User;
            var providerName = !string.IsNullOrWhiteSpace(user.FullName) ? user.FullName : "TaskBridge Specialist";

            // Multi-Criteria Scoring (MCDA) with real DB provider awareness
            var breakdown = CalculateScores(
                p.Category, 
                p.Skills ?? user.ProviderSkills, 
                p.ServiceAreas ?? user.ProviderServiceAreas, 
                p.HourlyRate, 
                p.Rating, 
                p.ReviewCount, 
                job,
                isRealDbProvider: true);

            var totalScore = (int)Math.Round(breakdown.SkillScore + breakdown.LocationScore + breakdown.BudgetScore + breakdown.RatingScore);
            totalScore = Math.Clamp(totalScore, 40, 98);

            candidatePool.Add(new MatchedProviderDto
            {
                ProviderId = p.Id,
                UserId = p.UserId,
                FullName = providerName,
                ProfilePhotoUrl = user.ProfilePhotoUrl,
                Phone = user.Phone,
                Category = p.Category,
                Skills = p.Skills ?? user.ProviderSkills,
                ServiceAreas = p.ServiceAreas ?? user.ProviderServiceAreas ?? "Colombo 05",
                DistanceKm = 2.4,
                HourlyRate = p.HourlyRate > 0 ? p.HourlyRate : 2500m,
                Rating = p.Rating > 0 ? p.Rating : 4.8,
                ReviewCount = p.ReviewCount > 0 ? p.ReviewCount : 24,
                MatchScore = totalScore,
                ScoreBreakdown = breakdown,
                AiMatchReason = "Specialized skills and strong service coverage in your area."
            });
        }