using System.Diagnostics;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

namespace backend.Api.AI;

public class CoordinationAgentService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly AuthDbContext _dbContext;
    private readonly ILogger<CoordinationAgentService> _logger;

    public CoordinationAgentService(
        HttpClient httpClient,
        IConfiguration configuration,
        AuthDbContext dbContext,
        ILogger<CoordinationAgentService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _dbContext = dbContext;
        _logger = logger;
    }

    /// <summary>
    /// Evaluates dynamic provider quotations against customer constraints,
    /// selects the winning best-fit proposal, and generates Explainable AI (XAI) rationale.
    /// </summary>
    public async Task<BookingProposalResponse> EvaluateQuotationsAsync(
        CoordinationEvaluateRequest request,
        CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        var plan = request.JobPlan;
        var quotes = request.CandidateProviders ?? new List<ProviderQuotationDto>();

        // If no quotations were provided by the caller, auto-generate competitive quotes for evaluation
        if (quotes.Count == 0)
        {
            quotes = GenerateFallbackQuotes(plan);
        }

        Console.ForegroundColor = ConsoleColor.Magenta;
        Console.WriteLine("\n============================================================");
        Console.WriteLine("[🤝 TASKBRIDGE AI: AGENT 3 - COORDINATION AGENT]");
        Console.WriteLine($"📋 Evaluating {quotes.Count} Quotation(s) for Job: \"{plan.ServiceTitle}\" ({plan.Category})");
        Console.WriteLine($"💰 Customer Budget: {(plan.Budget.HasValue ? $"Rs. {plan.Budget.Value:N0}" : "Flexible")}");
        Console.WriteLine($"⏰ Requested Time Window: {plan.ScheduledDate} {plan.ScheduledTime}");
        Console.WriteLine("============================================================\n");
        Console.ResetColor();

        // 1. Multi-Criteria Scoring of submitted quotations
        // Factors: Budget fit (40%), Schedule fit (30%), Rating & reputation (30%)
        ProviderQuotationDto? bestQuote = null;
        double highestScore = -1.0;

        foreach (var q in quotes)
        {
            double score = 0;

            // Budget Fit
            if (plan.Budget.HasValue && plan.Budget.Value > 0)
            {
                if (q.QuotedPrice <= plan.Budget.Value)
                {
                    var savings = (double)((plan.Budget.Value - q.QuotedPrice) / plan.Budget.Value);
                    score += 40.0 + Math.Min(savings * 10.0, 10.0);
                }
                else
                {
                    var over = (double)((q.QuotedPrice - plan.Budget.Value) / plan.Budget.Value);
                    score += Math.Max(0.0, 40.0 - (over * 50.0));
                }
            }
            else
            {
                score += 35.0; // Reasonable neutral score when budget is flexible
            }

            // Schedule Fit
            var timeWindow = plan.ScheduledTime.ToLowerInvariant();
            var avail = q.AvailableTime.ToLowerInvariant();
            if (timeWindow.Contains("morning") && (avail.Contains("am") || avail.Contains("morning") || avail.Contains("9:") || avail.Contains("10:")))
            {
                score += 30.0;
            }
            else if (timeWindow.Contains("afternoon") && (avail.Contains("pm") || avail.Contains("12:") || avail.Contains("1:") || avail.Contains("2:") || avail.Contains("3:") || avail.Contains("4:")))
            {
                score += 30.0;
            }
            else if (timeWindow.Contains("evening") && (avail.Contains("5:") || avail.Contains("6:") || avail.Contains("7:")))
            {
                score += 30.0;
            }
            else
            {
                score += 22.0;
            }

            // Rating & Proximity Fit
            score += (q.Rating / 5.0) * 20.0;
            score += Math.Max(0.0, 10.0 - (q.DistanceKm * 0.8));

            if (score > highestScore)
            {
                highestScore = score;
                bestQuote = q;
            }
        }

        bestQuote ??= quotes.FirstOrDefault() ?? new ProviderQuotationDto
        {
            ProviderId = "default-prov",
            FullName = "Ravindu Dissanayake",
            Category = plan.Category,
            QuotedPrice = plan.Budget ?? 4500m,
            AvailableTime = "Tomorrow at 9:30 AM",
            Rating = 4.8,
            ReviewCount = 12,
            DistanceKm = 2.4,
            Notes = "Includes complete cleanup and waste disposal."
        };

        

        // 3. Prepare the formal Booking Proposal (Exact Figma format: "17 Sep · 4:00 PM · Colombo 05")
        var propRef = await GenerateProposalReferenceAsync(ct);
        var datePart = string.IsNullOrWhiteSpace(plan.ScheduledDate) ? "Tomorrow" : plan.ScheduledDate.Split('·').First().Trim();
        var timePart = bestQuote.AvailableTime.Contains("at") ? bestQuote.AvailableTime.Split("at").Last().Trim() : "4:00 PM";
        var locPart = string.IsNullOrWhiteSpace(plan.Location) ? "Colombo 05" : plan.Location;
        var scheduleDisplay = $"{datePart} · {timePart} · {locPart}";

        var customerDisplayName = !string.IsNullOrWhiteSpace(request.CustomerName)
            ? request.CustomerName.Trim()
            : "Customer";

        var bookingProposal = new BookingDetailsDto
        {
            BookingReference = propRef,
            ServiceTitle = plan.ServiceTitle,
            ProviderName = bestQuote.FullName,
            CustomerId = request.CustomerId,
            CustomerName = customerDisplayName,
            Location = locPart,
            Schedule = scheduleDisplay,
            Price = bestQuote.QuotedPrice,
            PriceFormatted = $"Rs. {bestQuote.QuotedPrice:N0}/hr",
            Status = "Requested"
        };

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"[✅ TASKBRIDGE AI: AGENT 3] Recommendation: {bestQuote.FullName} (Rs. {bestQuote.QuotedPrice:N0})");
        Console.WriteLine($"[✅ TASKBRIDGE AI: AGENT 3] Proposal Ref: {bookingProposal.BookingReference} | Schedule: {bookingProposal.Schedule}");
        Console.WriteLine($"[⚡ TASKBRIDGE AI: AGENT 3] Latency: {sw.ElapsedMilliseconds} ms");
        Console.ResetColor();

        return new BookingProposalResponse
        {
            Success = true,
            RecommendedProviderId = bestQuote.ProviderId,
            RecommendedProviderName = bestQuote.FullName,
            RecommendationReason = recommendationReason,
            WinningQuotation = bestQuote,
            AllQuotations = quotes,
            BookingProposal = bookingProposal,
            Model = model,
            LatencyMs = sw.ElapsedMilliseconds
        };
    }

}