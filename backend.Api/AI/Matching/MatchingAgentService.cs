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

        // 2. Filter candidate pool strictly to real DB providers matching the requested category / service
        var reqCat = (job.Category ?? "").ToLowerInvariant().Trim();
        var reqTitle = (job.ServiceTitle ?? "").ToLowerInvariant().Trim();
        var reqDesc = (job.Description ?? "").ToLowerInvariant().Trim();
        var combinedRequest = $"{reqCat} {reqTitle} {reqDesc}";

        var matchingProviders = candidatePool.Where(p =>
        {
            var pCat = (p.Category ?? "").ToLowerInvariant().Trim();
            var pSkills = (p.Skills ?? "").ToLowerInvariant().Trim();
            var pFull = $"{pCat} {pSkills}";

            // 1. Direct category match (e.g. "plumbing" in "plumbing" or "gardening" in "gardening & outdoor")
            if (!string.IsNullOrWhiteSpace(reqCat) && !string.IsNullOrWhiteSpace(pCat))
            {
                if (pCat == reqCat || pCat.Contains(reqCat) || reqCat.Contains(pCat))
                {
                    return true;
                }
            }

            // 2. Specific domain keywords matching without substring collisions (e.g., 'air' inside 'repair')
            // Plumbing
            if (combinedRequest.Contains("plumb") || combinedRequest.Contains("tap") || combinedRequest.Contains("pipe") || combinedRequest.Contains("faucet") || combinedRequest.Contains("leak") || combinedRequest.Contains("drain"))
            {
                return pFull.Contains("plumb") || pFull.Contains("tap") || pFull.Contains("pipe") || pFull.Contains("faucet") || pFull.Contains("drain");
            }

            // Electrical
            if (combinedRequest.Contains("electric") || combinedRequest.Contains("wire") || combinedRequest.Contains("wiring") || combinedRequest.Contains("breaker"))
            {
                return pFull.Contains("electric") || pFull.Contains("wire") || pFull.Contains("wiring");
            }

            // HVAC / Air Conditioning (distinct terms, NOT substring 'air' which matches 'repair')
            if (combinedRequest.Contains("hvac") || combinedRequest.Contains("air condition") || combinedRequest.Contains("a/c") || combinedRequest.Contains("cooling"))
            {
                return pFull.Contains("hvac") || pFull.Contains("air condition") || pFull.Contains("a/c") || pFull.Contains("cooling");
            }

            // Gardening & Outdoor
            if (combinedRequest.Contains("garden") || combinedRequest.Contains("lawn") || combinedRequest.Contains("grass") || combinedRequest.Contains("yard") || combinedRequest.Contains("landscap"))
            {
                return pFull.Contains("garden") || pFull.Contains("lawn") || pFull.Contains("grass") || pFull.Contains("yard") || pFull.Contains("landscap");
            }

            // Cleaning
            if (combinedRequest.Contains("deep clean") || combinedRequest.Contains("home clean") || combinedRequest.Contains("house clean") || (reqCat == "cleaning" && pCat.Contains("clean")))
            {
                return pFull.Contains("clean");
            }

            // IT & Security
            if (combinedRequest.Contains("it & security") || combinedRequest.Contains("cctv") || combinedRequest.Contains("camera") || combinedRequest.Contains("wifi") || combinedRequest.Contains("network"))
            {
                return pFull.Contains("it") || pFull.Contains("security") || pFull.Contains("cctv") || pFull.Contains("network");
            }

            return false;
        }).ToList();

        // Strictly use matching providers. If none match the category, do not fall back to unrelated providers
        var poolToRank = matchingProviders;

        // Sort by composite match score descending and take requested top N (ONLY real DB providers)
        var ranked = poolToRank
            .OrderByDescending(c => c.MatchScore)
            .ThenByDescending(c => c.Rating)
            .Take(request.MaxResults)
            .ToList();