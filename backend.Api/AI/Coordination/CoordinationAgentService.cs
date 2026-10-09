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

        // Mark winning quote
        foreach (var q in quotes)
        {
            q.IsRecommended = (q.ProviderId == bestQuote.ProviderId);
        }

        // 2. Generate Explainable AI (XAI) rationale via OpenAI or fallback
        string recommendationReason;
        var apiKey = _configuration["OpenAI:ApiKey"]
            ?? Environment.GetEnvironmentVariable("OPENAI_API_KEY")
            ?? string.Empty;
        var model = _configuration["OpenAI:Model"] ?? "gpt-4o-mini";

        if (!string.IsNullOrWhiteSpace(apiKey) && !apiKey.StartsWith("YOUR_"))
        {
            recommendationReason = await GenerateOpenAiRationaleAsync(plan, bestQuote, quotes, apiKey, model, ct);
        }
        else
        {
            recommendationReason = GenerateRuleBasedRationale(plan, bestQuote);
        }

        sw.Stop();

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

    private async Task<Guid?> ResolveCustomerIdAsync(string? customerId, string? customerName, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(customerId) && Guid.TryParse(customerId, out var parsedGuid))
        {
            return parsedGuid;
        }
        if (!string.IsNullOrWhiteSpace(customerName) && customerName.Trim().ToLowerInvariant() != "customer")
        {
            var cName = customerName.Trim().ToLowerInvariant();
            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.FullName.ToLower() == cName, ct);
            if (user != null) return user.Id;
        }
        return null;
    }

    private async Task<Guid?> ResolveProviderIdAsync(string? providerId, string? providerName, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(providerId) && Guid.TryParse(providerId, out var parsedGuid))
        {
            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == parsedGuid, ct);
            if (user != null) return user.Id;

            var profile = await _dbContext.Providers.FirstOrDefaultAsync(p => p.Id == parsedGuid, ct);
            if (profile != null) return profile.UserId;

            return parsedGuid;
        }

        if (!string.IsNullOrWhiteSpace(providerName))
        {
            var pName = providerName.Trim().ToLowerInvariant();
            var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.FullName.ToLower() == pName, ct);
            if (user != null) return user.Id;
        }

        return null;
    }

    private async Task BackfillMissingCustomerIdsAsync(CancellationToken ct)
    {
        try
        {
            var nullProposals = await _dbContext.Proposals.Where(p => p.CustomerId == null).OrderByDescending(p => p.CreatedAt).Take(20).ToListAsync(ct);
            bool changed = false;
            foreach (var p in nullProposals)
            {
                var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.FullName.ToLower() == p.CustomerName.Trim().ToLower(), ct);
                if (user != null)
                {
                    p.CustomerId = user.Id;
                    changed = true;
                }
            }

            var nullBookings = await _dbContext.Bookings.Where(b => b.CustomerId == null).OrderByDescending(b => b.CreatedAt).Take(20).ToListAsync(ct);
            foreach (var b in nullBookings)
            {
                var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.FullName.ToLower() == b.CustomerName.Trim().ToLower(), ct);
                if (user != null)
                {
                    b.CustomerId = user.Id;
                    changed = true;
                }
            }

            if (changed)
            {
                await _dbContext.SaveChangesAsync(ct);
            }
        }
        catch
        {
            // best-effort backfill
        }
    }

    /// <summary>
    /// Confirms the booking upon customer approval (Human-in-the-Loop) and writes to DB.
    /// </summary>
    public async Task<BookingEntity> ConfirmBookingAsync(ConfirmBookingRequest req, CancellationToken ct = default)
    {
        var bookingRef = !string.IsNullOrWhiteSpace(req.BookingReference) && req.BookingReference.StartsWith("TB-")
            ? req.BookingReference
            : await GenerateBookingReferenceAsync(ct);

        var existing = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.BookingReference == bookingRef, ct);
        if (existing != null)
        {
            existing.Status = req.Status ?? "Upcoming";
            if (req.Price > 0) existing.Price = req.Price;
            if (!string.IsNullOrWhiteSpace(req.RateType)) existing.RateType = req.RateType;
            if (!string.IsNullOrWhiteSpace(req.ProviderName)) existing.ProviderName = req.ProviderName;
            existing.UpdatedAt = DateTimeOffset.UtcNow;
            await _dbContext.SaveChangesAsync(ct);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"[🎉 BOOKING CONFIRMED] Ref: {existing.BookingReference} | Provider: {existing.ProviderName} | Price: Rs. {existing.Price:N0} ({existing.RateType})");
            Console.ResetColor();
            return existing;
        }

        Guid? provId = await ResolveProviderIdAsync(req.ProviderId, req.ProviderName, ct);
        Guid? custId = await ResolveCustomerIdAsync(req.CustomerId, req.CustomerName, ct);

        var entity = new BookingEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = bookingRef,
            CustomerId = custId,
            CustomerName = req.CustomerName ?? "Customer",
            ProviderId = provId,
            ProviderName = req.ProviderName,
            ServiceTitle = req.ServiceTitle,
            Category = req.Category,
            Location = req.Location,
            Schedule = req.Schedule,
            Price = req.Price,
            RateType = !string.IsNullOrWhiteSpace(req.RateType) ? req.RateType : "Hourly",
            Status = req.Status ?? "Upcoming",
            CreatedAt = DateTimeOffset.UtcNow
        };

        _dbContext.Bookings.Add(entity);
        await _dbContext.SaveChangesAsync(ct);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"[🎉 BOOKING CONFIRMED] Ref: {entity.BookingReference} | Provider: {entity.ProviderName} | CustomerId: {entity.CustomerId} | Price: Rs. {entity.Price:N0} ({entity.RateType})");
        Console.ResetColor();

        return entity;
    }

    /// <summary>
    /// Persists an open proposal (status = "Pending") into the 'proposals' table.
    /// </summary>
    public async Task<ProposalEntity> CreateProposalAsync(CreateQuotationRequest req, CancellationToken ct = default)
    {
        var proposalRef = !string.IsNullOrWhiteSpace(req.BookingReference)
            ? (req.BookingReference.StartsWith("PR-") ? req.BookingReference : req.BookingReference.Replace("TB-", "PR-"))
            : await GenerateProposalReferenceAsync(ct);

        Guid? custId = await ResolveCustomerIdAsync(req.CustomerId, req.CustomerName, ct);
        Guid? provId = await ResolveProviderIdAsync(req.ProviderId, req.ProviderName, ct);

        var existing = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == proposalRef, ct);
        if (existing != null)
        {
            existing.EstimatedRate = req.Price;
            if (!string.IsNullOrWhiteSpace(req.RateType)) existing.RateType = req.RateType;
            existing.PreferredSchedule = req.Schedule;
            existing.Location = req.Location;
            existing.ServiceTitle = req.ServiceTitle;
            existing.Category = req.Category;
            if (!string.IsNullOrWhiteSpace(req.Notes)) existing.Notes = req.Notes;
            if (custId.HasValue)
            {
                existing.CustomerId = custId;
            }
            if (!string.IsNullOrWhiteSpace(req.CustomerName))
            {
                existing.CustomerName = req.CustomerName;
            }
            existing.Status = string.IsNullOrWhiteSpace(req.Status) ? "Pending" : req.Status;
            existing.UpdatedAt = DateTimeOffset.UtcNow;

            // Also update linked booking in 'bookings' table
            var existingBooking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.ProposalId == existing.Id || b.BookingReference == proposalRef, ct);
            if (existingBooking != null)
            {
                existingBooking.Price = req.Price;
                if (!string.IsNullOrWhiteSpace(req.RateType)) existingBooking.RateType = req.RateType;
                existingBooking.Schedule = req.Schedule;
                existingBooking.Location = req.Location;
                existingBooking.ServiceTitle = req.ServiceTitle;
                existingBooking.Category = req.Category;
                if (!string.IsNullOrWhiteSpace(req.Notes)) existingBooking.Notes = req.Notes;
                if (custId.HasValue) existingBooking.CustomerId = custId;
                if (!string.IsNullOrWhiteSpace(req.CustomerName)) existingBooking.CustomerName = req.CustomerName;
                existingBooking.Status = string.IsNullOrWhiteSpace(req.Status) ? "Requested" : req.Status;
                existingBooking.UpdatedAt = DateTimeOffset.UtcNow;
            }
            else
            {
                _dbContext.Bookings.Add(new BookingEntity
                {
                    Id = Guid.NewGuid(),
                    BookingReference = proposalRef,
                    ProposalId = existing.Id,
                    CustomerId = custId,
                    CustomerName = req.CustomerName ?? "Customer",
                    ProviderId = provId,
                    ProviderName = req.ProviderName,
                    ServiceTitle = req.ServiceTitle,
                    Category = req.Category,
                    Location = req.Location,
                    Schedule = req.Schedule,
                    Price = req.Price,
                    RateType = !string.IsNullOrWhiteSpace(req.RateType) ? req.RateType : "Hourly",
                    Notes = req.Notes,
                    Status = string.IsNullOrWhiteSpace(req.Status) ? "Requested" : req.Status,
                    CreatedAt = DateTimeOffset.UtcNow
                });
            }

            await _dbContext.SaveChangesAsync(ct);
            return existing;
        }

        var entity = new ProposalEntity
        {
            Id = Guid.NewGuid(),
            ProposalReference = proposalRef,
            CustomerId = custId,
            CustomerName = req.CustomerName ?? "Customer",
            ProviderId = provId,
            ProviderName = req.ProviderName,
            ServiceTitle = req.ServiceTitle,
            Category = req.Category,
            Location = req.Location,
            PreferredSchedule = req.Schedule,
            EstimatedRate = req.Price,
            RateType = !string.IsNullOrWhiteSpace(req.RateType) ? req.RateType : "Hourly",
            Notes = req.Notes,
            Status = "Pending",
            CreatedAt = DateTimeOffset.UtcNow
        };

        _dbContext.Proposals.Add(entity);

        // Also persist linked entry in 'bookings' table
        var newBooking = new BookingEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = proposalRef,
            ProposalId = entity.Id,
            CustomerId = custId,
            CustomerName = req.CustomerName ?? "Customer",
            ProviderId = provId,
            ProviderName = req.ProviderName,
            ServiceTitle = req.ServiceTitle,
            Category = req.Category,
            Location = req.Location,
            Schedule = req.Schedule,
            Price = req.Price,
            RateType = !string.IsNullOrWhiteSpace(req.RateType) ? req.RateType : "Hourly",
            Notes = req.Notes,
            Status = string.IsNullOrWhiteSpace(req.Status) ? "Requested" : req.Status,
            CreatedAt = DateTimeOffset.UtcNow
        };
        _dbContext.Bookings.Add(newBooking);

        await _dbContext.SaveChangesAsync(ct);

        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine($"[📝 PROPOSAL & BOOKING PERSISTED] Ref: {entity.ProposalReference} | Provider: {entity.ProviderName} | CustomerId: {entity.CustomerId} | Status: {entity.Status}");
        Console.ResetColor();

        return entity;
    }

    /// <summary>
    /// Provider accepts a customer proposal:
    /// 1. Updates proposal in 'proposals' table to Status = 'Accepted'.
    /// 2. Updates or creates confirmed appointment in 'bookings' table (Status = 'Upcoming').
    /// </summary>
    public async Task<BookingEntity?> AcceptProposalAsync(AcceptProposalRequest req, CancellationToken ct = default)
    {
        var proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == req.ProposalReference, ct);
        if (proposal == null)
        {
            var altRef = req.ProposalReference.StartsWith("TB-")
                ? req.ProposalReference.Replace("TB-", "PR-")
                : req.ProposalReference.Replace("PR-", "TB-");
            proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == altRef, ct);
        }

        if (proposal == null)
        {
            var linkedB = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.BookingReference == req.ProposalReference, ct);
            if (linkedB?.ProposalId != null)
            {
                proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.Id == linkedB.ProposalId.Value, ct);
            }
        }

        if (proposal == null) return null;

        Guid? bookingCustId = proposal.CustomerId ?? await ResolveCustomerIdAsync(null, proposal.CustomerName, ct);
        if (!proposal.CustomerId.HasValue && bookingCustId.HasValue)
        {
            proposal.CustomerId = bookingCustId;
        }

        // Check if an existing booking is already linked to this proposal
        var linkedBooking = await _dbContext.Bookings.FirstOrDefaultAsync(b =>
            b.ProposalId == proposal.Id ||
            b.BookingReference == proposal.ProposalReference ||
            b.BookingReference == proposal.ProposalReference.Replace("PR-", "TB-") ||
            b.BookingReference == proposal.ProposalReference.Replace("TB-", "PR-"), ct);

        // Always resolve the agreed price from the proposal's updated rebid rate first
        decimal resolvedAgreedPrice = req.ConfirmedPrice > 0
            ? req.ConfirmedPrice
            : (proposal.EstimatedRate > 0 ? proposal.EstimatedRate : (linkedBooking?.Price > 0 ? linkedBooking.Price : 2500m));

        if (proposal.EstimatedRate > 0 && req.ConfirmedPrice <= 0)
        {
            resolvedAgreedPrice = proposal.EstimatedRate;
        }

        proposal.Status = "Accepted";
        proposal.EstimatedRate = resolvedAgreedPrice;
        proposal.UpdatedAt = DateTimeOffset.UtcNow;

        if (linkedBooking != null)
        {
            linkedBooking.Status = "Upcoming";
            linkedBooking.Schedule = !string.IsNullOrWhiteSpace(req.ConfirmedSchedule) ? req.ConfirmedSchedule : proposal.PreferredSchedule;
            linkedBooking.Price = resolvedAgreedPrice;
            if (!string.IsNullOrWhiteSpace(req.RateType)) linkedBooking.RateType = req.RateType;
            if (bookingCustId.HasValue) linkedBooking.CustomerId = bookingCustId;
            linkedBooking.UpdatedAt = DateTimeOffset.UtcNow;

            await _dbContext.SaveChangesAsync(ct);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"[🎉 LINKED BOOKING CONFIRMED] Proposal: {proposal.ProposalReference} -> Booking: {linkedBooking.BookingReference} | CustomerId: {linkedBooking.CustomerId} | Price: Rs. {linkedBooking.Price:N0} ({linkedBooking.RateType}) | Schedule: {linkedBooking.Schedule}");
            Console.ResetColor();

            return linkedBooking;
        }

        var bookingRef = await GenerateBookingReferenceAsync(ct);
        var confirmedBooking = new BookingEntity
        {
            Id = Guid.NewGuid(),
            BookingReference = bookingRef,
            ProposalId = proposal.Id,
            CustomerId = bookingCustId,
            CustomerName = proposal.CustomerName,
            ProviderId = proposal.ProviderId,
            ProviderName = proposal.ProviderName,
            ServiceTitle = proposal.ServiceTitle,
            Category = proposal.Category,
            Location = proposal.Location,
            Schedule = !string.IsNullOrWhiteSpace(req.ConfirmedSchedule) ? req.ConfirmedSchedule : proposal.PreferredSchedule,
            Price = resolvedAgreedPrice,
            RateType = !string.IsNullOrWhiteSpace(req.RateType) ? req.RateType : proposal.RateType,
            Notes = proposal.Notes,
            Status = "Upcoming",
            CreatedAt = DateTimeOffset.UtcNow
        };

        _dbContext.Bookings.Add(confirmedBooking);
        await _dbContext.SaveChangesAsync(ct);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine($"[🎉 PROPOSAL ACCEPTED -> NEW BOOKING CREATED] Proposal: {proposal.ProposalReference} -> Booking: {confirmedBooking.BookingReference} | CustomerId: {confirmedBooking.CustomerId} | Price: Rs. {confirmedBooking.Price:N0} ({confirmedBooking.RateType}) | Schedule: {confirmedBooking.Schedule}");
        Console.ResetColor();

        return confirmedBooking;
    }

    /// <summary>
    /// Provider declines a customer proposal.
    /// </summary>
    public async Task<ProposalEntity?> DeclineProposalAsync(DeclineProposalRequest req, CancellationToken ct = default)
    {
        var proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == req.ProposalReference, ct);
        if (proposal == null)
        {
            var altRef = req.ProposalReference.Replace("TB-", "PR-");
            proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == altRef, ct);
        }

        if (proposal == null) return null;

        proposal.Status = "Declined";
        proposal.UpdatedAt = DateTimeOffset.UtcNow;

        var linkedB = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
            b.ProposalId == proposal.Id || 
            b.BookingReference == proposal.ProposalReference ||
            b.BookingReference == proposal.ProposalReference.Replace("PR-", "TB-"), ct);
        if (linkedB != null)
        {
            linkedB.Status = "Cancelled";
            linkedB.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await _dbContext.SaveChangesAsync(ct);

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine($"[❌ PROPOSAL DECLINED] Ref: {proposal.ProposalReference} | Reason: {req.Reason ?? "Declined by provider"}");
        Console.ResetColor();

        return proposal;
    }

    /// <summary>
    /// Generates the next sequential Booking Reference starting at TB-1000.
    /// </summary>
    public async Task<string> GenerateBookingReferenceAsync(CancellationToken ct = default)
    {
        var allRefs = await _dbContext.Bookings
            .Where(b => b.BookingReference.StartsWith("TB-"))
            .Select(b => b.BookingReference)
            .ToListAsync(ct);

        int maxNumber = 999;
        foreach (var r in allRefs)
        {
            var parts = r.Split('-');
            if (parts.Length > 1 && int.TryParse(parts[1], out var num) && num > maxNumber)
            {
                maxNumber = num;
            }
        }
        return $"TB-{maxNumber + 1}";
    }

    /// <summary>
    /// Generates the next sequential Proposal Reference starting at PR-1000.
    /// </summary>
    public async Task<string> GenerateProposalReferenceAsync(CancellationToken ct = default)
    {
        var allRefs = await _dbContext.Proposals
            .Where(p => p.ProposalReference.StartsWith("PR-"))
            .Select(p => p.ProposalReference)
            .ToListAsync(ct);

        int maxNumber = 999;
        foreach (var r in allRefs)
        {
            var parts = r.Split('-');
            if (parts.Length > 1 && int.TryParse(parts[1], out var num) && num > maxNumber)
            {
                maxNumber = num;
            }
        }
        return $"PR-{maxNumber + 1}";
    }


    /// <summary>
    /// Retrieves live proposals from 'proposals' table.
    /// </summary>
    public async Task<List<ProposalEntity>> GetProposalsAsync(
        string? providerId = null,
        string? providerName = null,
        string? customerName = null,
        string? status = null,
        CancellationToken ct = default)
    {
        await BackfillMissingCustomerIdsAsync(ct);
        var query = _dbContext.Proposals.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(providerId) && Guid.TryParse(providerId, out var pGuid))
        {
            var profileIds = await _dbContext.Providers
                .Where(p => p.Id == pGuid || p.UserId == pGuid)
                .Select(p => p.Id)
                .ToListAsync(ct);
            profileIds.Add(pGuid);

            // Strict provider ID matching
            query = query.Where(p => p.ProviderId.HasValue && profileIds.Contains(p.ProviderId.Value));
        }
        else if (!string.IsNullOrWhiteSpace(providerName))
        {
            var pLow = providerName.Trim().ToLowerInvariant();
            query = query.Where(p => p.ProviderName.ToLower() == pLow);
        }

        if (!string.IsNullOrWhiteSpace(customerName))
        {
            var cLow = customerName.Trim().ToLowerInvariant();
            query = query.Where(p => p.CustomerName.ToLower().Contains(cLow) || cLow.Contains(p.CustomerName.ToLower()) || p.CustomerName.ToLower() == "customer");
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            var sLow = status.Trim().ToLowerInvariant();
            if (sLow == "pending" || sLow == "requested")
            {
                query = query.Where(p => p.Status.ToLower() == "pending" ||
                                         p.Status.ToLower() == "requested" ||
                                         p.Status.ToLower() == "customercountered" ||
                                         p.Status.ToLower() == "providercountered");
            }
            else
            {
                query = query.Where(p => p.Status.ToLower() == sLow);
            }
        }

        return await query.OrderByDescending(p => p.CreatedAt).ToListAsync(ct);
    }

    /// <summary>
    /// Evaluates a rebid against the provider's standard hourly rate and issues cognitive warnings if pricing is out of balance.
    /// </summary>
    public async Task<RebidEvaluationResult> EvaluateRebidAsync(EvaluateRebidRequest req, CancellationToken ct = default)
    {
        var isCustomer = string.Equals(req.SenderRole, "customer", StringComparison.OrdinalIgnoreCase);
        var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.BookingReference == req.BookingReference, ct);
        var proposal = booking == null
            ? await _dbContext.Proposals.FirstOrDefaultAsync(p => p.ProposalReference == req.BookingReference, ct)
            : null;

        var providerId = booking?.ProviderId ?? proposal?.ProviderId;
        var providerName = booking?.ProviderName ?? proposal?.ProviderName ?? "Provider";
        var serviceTitle = booking?.ServiceTitle ?? proposal?.ServiceTitle ?? "Service";

        // 1. Resolve standard hourly rate from ProviderProfile, proposal, or booking
        decimal standardRate = 0m;
        if (providerId.HasValue)
        {
            var profile = await _dbContext.Providers.FirstOrDefaultAsync(p => p.UserId == providerId.Value, ct);
            if (profile != null && profile.HourlyRate > 0)
            {
                standardRate = profile.HourlyRate;
            }
        }

        if (standardRate == 0m && !string.IsNullOrWhiteSpace(providerName))
        {
            var profile = await _dbContext.Providers
                .Include(p => p.User)
                .FirstOrDefaultAsync(p => p.User != null && p.User.FullName.ToLower() == providerName.ToLower(), ct);
            if (profile != null && profile.HourlyRate > 0)
            {
                standardRate = profile.HourlyRate;
            }
        }

        if (standardRate == 0m)
        {
            if (proposal != null && proposal.EstimatedRate > 0) standardRate = proposal.EstimatedRate;
            else if (booking != null && booking.Price > 0) standardRate = booking.Price;
            else standardRate = 2500m; // Default benchmark rate
        }

        // 2. Compute variance
        var proposedPrice = req.ProposedPrice;
        double variancePct = standardRate > 0
            ? (double)Math.Round(((proposedPrice - standardRate) / standardRate) * 100, 1)
            : 0;

        bool hasWarning = false;
        string? warningMessage = null;
        string advisoryType = "Balanced";

        if (!isCustomer)
        {
            // PROVIDER REBID: Check if higher than standard hourly rate
            if (proposedPrice > standardRate)
            {
                hasWarning = true;
                advisoryType = "RateHigherThanBenchmark";
                warningMessage = $"Your registered profile hourly rate is Rs. {standardRate:N0}/hr. This proposal rebid (Rs. {proposedPrice:N0}/hr) is {variancePct:+0.0}% higher than your actual rate. This higher rate may lower your chance of customer acceptance.";
            }
        }
        else
        {
            // CUSTOMER REBID: Check if lower than provider standard rate
            if (proposedPrice < standardRate)
            {
                hasWarning = true;
                advisoryType = "RateLowerThanBenchmark";
                var discountPct = Math.Abs(variancePct);
                warningMessage = $"Warning: Your offered price of Rs. {proposedPrice:N0} is {discountPct:0.0}% lower than {providerName}'s actual rate of Rs. {standardRate:N0}/hr. Providers are less likely to accept bids significantly below their benchmark rate.";
            }
        }

        // 3. Log to console for terminal evidence
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("\n============================================================");
        Console.WriteLine("[🤝 TASKBRIDGE AI: AGENT 3 - COORDINATION AGENT: REBID EVALUATION]");
        Console.WriteLine($"📋 Target Reference: {req.BookingReference} | Service: \"{serviceTitle}\"");
        Console.WriteLine($"👤 Rebid Submitted By: {(isCustomer ? "CUSTOMER" : "PROVIDER")} ({providerName})");
        Console.WriteLine($"💰 Standard Benchmark Rate: Rs. {standardRate:N0}/hr");
        Console.WriteLine($"📊 Proposed Rebid Price:    Rs. {proposedPrice:N0} ({(variancePct >= 0 ? "+" : "")}{variancePct:0.0}%)");
        if (hasWarning)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"⚠️ AGENT ADVISORY: {warningMessage}");
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ AGENT EVALUATION: Rebid price is balanced and aligned with standard rate.");
        }
        Console.WriteLine("============================================================\n");
        Console.ResetColor();

        return new RebidEvaluationResult
        {
            HasAgentWarning = hasWarning,
            AgentWarning = warningMessage,
            AgentAdvisoryType = advisoryType,
            StandardHourlyRate = standardRate,
            ProposedPrice = proposedPrice,
            VariancePercentage = variancePct,
            ProviderName = providerName,
            ServiceTitle = serviceTitle,
            SenderRole = isCustomer ? "customer" : "provider"
        };
    }

    /// <summary>
    /// Submits a counter-bid / rebid and evaluates against provider's standard hourly rate.
    /// </summary>
    public async Task<CounterBidResultDto> SubmitCounterBidWithEvaluationAsync(ProviderCounterBidRequest req, CancellationToken ct = default)
    {
        // 1. Run Coordination Agent evaluation
        var evalReq = new EvaluateRebidRequest
        {
            BookingReference = req.BookingReference,
            ProposedPrice = req.CounterPrice,
            SenderRole = req.Sender ?? "provider"
        };
        var evaluation = await EvaluateRebidAsync(evalReq, ct);

        // 2. Apply status and price update
        var updated = await SubmitCounterBidAsync(req, ct);

        return new CounterBidResultDto
        {
            Success = updated != null,
            Booking = updated,
            Evaluation = evaluation
        };
    }

    /// <summary>
    /// Allows a provider or customer to submit a counter-bid / updated quote.
    /// </summary>
    public async Task<BookingEntity?> SubmitCounterBidAsync(ProviderCounterBidRequest req, CancellationToken ct = default)
    {
        var isCustomer = string.Equals(req.Sender, "customer", StringComparison.OrdinalIgnoreCase);
        var targetStatus = isCustomer ? "CustomerCountered" : "ProviderCountered";

        var altRef = req.BookingReference.StartsWith("TB-")
            ? req.BookingReference.Replace("TB-", "PR-")
            : req.BookingReference.Replace("PR-", "TB-");

        var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
            b.BookingReference == req.BookingReference || b.BookingReference == altRef, ct);

        var proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => 
            p.ProposalReference == req.BookingReference || p.ProposalReference == altRef ||
            (booking != null && booking.ProposalId.HasValue && p.Id == booking.ProposalId.Value), ct);

        if (booking == null && proposal == null)
        {
            return null;
        }

        if (booking != null)
        {
            if (string.Equals(booking.Status, "In Progress", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(booking.Status, "Active", StringComparison.OrdinalIgnoreCase) ||
                booking.StartedAt.HasValue)
            {
                throw new InvalidOperationException("Cannot modify terms because the service is already in progress.");
            }

            booking.Price = req.CounterPrice;
            if (!string.IsNullOrWhiteSpace(req.RateType))
            {
                booking.RateType = req.RateType;
            }
            if (!string.IsNullOrWhiteSpace(req.AvailableTime))
            {
                booking.Schedule = $"{req.AvailableTime} · {booking.Location}";
            }
            booking.Status = targetStatus;
            booking.UpdatedAt = DateTimeOffset.UtcNow;
        }

        if (proposal != null)
        {
            proposal.EstimatedRate = req.CounterPrice;
            if (!string.IsNullOrWhiteSpace(req.RateType))
            {
                proposal.RateType = req.RateType;
            }
            if (!string.IsNullOrWhiteSpace(req.AvailableTime))
            {
                proposal.PreferredSchedule = $"{req.AvailableTime} · {proposal.Location}";
            }
            proposal.Status = targetStatus;
            proposal.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await _dbContext.SaveChangesAsync(ct);

        if (booking != null)
        {
            return booking;
        }

        return new BookingEntity
        {
            Id = proposal!.Id,
            BookingReference = proposal.ProposalReference,
            CustomerId = proposal.CustomerId,
            CustomerName = proposal.CustomerName,
            ProviderId = proposal.ProviderId,
            ProviderName = proposal.ProviderName,
            ServiceTitle = proposal.ServiceTitle,
            Category = proposal.Category,
            Location = proposal.Location,
            Schedule = proposal.PreferredSchedule,
            Price = proposal.EstimatedRate,
            RateType = proposal.RateType,
            Status = targetStatus
        };
    }

    /// <summary>
    /// Cancels an active quotation request or booking upon customer or provider cancellation.
    /// </summary>
    public async Task<BookingEntity?> CancelBookingAsync(CancelBookingRequest req, CancellationToken ct = default)
    {
        var booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
            b.BookingReference == req.BookingReference ||
            b.BookingReference == req.BookingReference.Replace("PR-", "TB-"), ct);

        if (booking != null)
        {
            if (string.Equals(booking.Status, "In Progress", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(booking.Status, "Active", StringComparison.OrdinalIgnoreCase) ||
                booking.StartedAt.HasValue)
            {
                throw new InvalidOperationException("Cannot cancel booking because the service is already in progress.");
            }

            booking.Status = "Cancelled";
            booking.UpdatedAt = DateTimeOffset.UtcNow;

            if (booking.ProposalId.HasValue)
            {
                var p = await _dbContext.Proposals.FirstOrDefaultAsync(x => x.Id == booking.ProposalId.Value, ct);
                if (p != null)
                {
                    p.Status = "Cancelled";
                    p.UpdatedAt = DateTimeOffset.UtcNow;
                }
            }
            var pByRef = await _dbContext.Proposals.FirstOrDefaultAsync(x => 
                x.ProposalReference == booking.BookingReference || 
                x.ProposalReference == booking.BookingReference.Replace("TB-", "PR-"), ct);
            if (pByRef != null)
            {
                pByRef.Status = "Cancelled";
                pByRef.UpdatedAt = DateTimeOffset.UtcNow;
            }

            await _dbContext.SaveChangesAsync(ct);
            return booking;
        }

        var proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => 
            p.ProposalReference == req.BookingReference ||
            p.ProposalReference == req.BookingReference.Replace("TB-", "PR-"), ct);

        if (proposal != null)
        {
            proposal.Status = "Cancelled";
            proposal.UpdatedAt = DateTimeOffset.UtcNow;

            var linkedB = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
                b.ProposalId == proposal.Id || 
                b.BookingReference == proposal.ProposalReference ||
                b.BookingReference == proposal.ProposalReference.Replace("PR-", "TB-"), ct);
            if (linkedB != null)
            {
                linkedB.Status = "Cancelled";
                linkedB.UpdatedAt = DateTimeOffset.UtcNow;
            }

            await _dbContext.SaveChangesAsync(ct);
            return new BookingEntity
            {
                Id = proposal.Id,
                BookingReference = proposal.ProposalReference,
                CustomerId = proposal.CustomerId,
                CustomerName = proposal.CustomerName,
                ProviderId = proposal.ProviderId,
                ProviderName = proposal.ProviderName,
                ServiceTitle = proposal.ServiceTitle,
                Category = proposal.Category,
                Location = proposal.Location,
                Schedule = proposal.PreferredSchedule,
                Price = proposal.EstimatedRate,
                RateType = proposal.RateType,
                Status = "Cancelled"
            };
        }

        return null;
    }

    /// <summary>
    /// Retrieves live bookings for a provider or customer.
    /// </summary>
    public async Task<List<BookingEntity>> GetBookingsAsync(
        string? providerId = null,
        string? providerName = null,
        string? customerName = null,
        string? status = null,
        CancellationToken ct = default)
    {
        await BackfillMissingCustomerIdsAsync(ct);
        var query = _dbContext.Bookings.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(providerId) && Guid.TryParse(providerId, out var provGuid))
        {
            var profileIds = await _dbContext.Providers
                .Where(p => p.Id == provGuid || p.UserId == provGuid)
                .Select(p => p.Id)
                .ToListAsync(ct);
            profileIds.Add(provGuid);

            // Strict provider ID matching
            query = query.Where(b => b.ProviderId.HasValue && profileIds.Contains(b.ProviderId.Value));
        }
        else if (!string.IsNullOrWhiteSpace(providerName))
        {
            var pLow = providerName.Trim().ToLowerInvariant();
            query = query.Where(b => b.ProviderName.ToLower() == pLow);
        }

        if (!string.IsNullOrWhiteSpace(customerName))
        {
            var cLow = customerName.Trim().ToLowerInvariant();
            query = query.Where(b => b.CustomerName.ToLower().Contains(cLow) || cLow.Contains(b.CustomerName.ToLower()) || b.CustomerName.ToLower() == "customer");
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            var sLow = status.Trim().ToLowerInvariant();
            query = query.Where(b => b.Status.ToLower() == sLow);
        }

        var rawList = await query.OrderByDescending(b => b.CreatedAt).ToListAsync(ct);

        // Deduplicate bookings where one is PR-xxxx and one is TB-xxxx for the same job
        var deduped = new List<BookingEntity>();
        var seenKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Sort so that active, countered, or confirmed bookings take precedence over stale initial requests
        var orderedList = rawList
            .OrderByDescending(b => b.Status == "Upcoming" || b.Status == "In Progress" || b.Status == "Completed" || b.Status == "CustomerCountered" || b.Status == "ProviderCountered")
            .ThenByDescending(b => b.UpdatedAt ?? b.CreatedAt)
            .ThenByDescending(b => b.BookingReference.StartsWith("TB-", StringComparison.OrdinalIgnoreCase))
            .ToList();

        foreach (var b in orderedList)
        {
            var baseKey = b.ProposalId.HasValue 
                ? b.ProposalId.Value.ToString()
                : b.BookingReference.Replace("TB-", "", StringComparison.OrdinalIgnoreCase).Replace("PR-", "", StringComparison.OrdinalIgnoreCase);
            
            if (seenKeys.Add(baseKey))
            {
                deduped.Add(b);
            }
        }

        return deduped.OrderByDescending(b => b.CreatedAt).ToList();
    }

    /// <summary>
    /// Updates status of a booking (e.g. Upcoming -> Active -> Completed).
    /// </summary>
    public async Task<BookingEntity?> UpdateBookingStatusAsync(UpdateBookingStatusRequest req, CancellationToken ct = default)
    {
        BookingEntity? booking = null;
        if (req.BookingId.HasValue)
        {
            booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => b.Id == req.BookingId.Value, ct);
        }
        else if (!string.IsNullOrWhiteSpace(req.BookingReference))
        {
            booking = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
                b.BookingReference == req.BookingReference ||
                b.BookingReference == req.BookingReference.Replace("PR-", "TB-"), ct);
        }

        if (booking != null)
        {
            booking.Status = req.NewStatus;
            if (!string.IsNullOrWhiteSpace(req.Schedule)) booking.Schedule = req.Schedule;
            if (req.Price.HasValue && req.Price.Value > 0) booking.Price = req.Price.Value;
            booking.UpdatedAt = DateTimeOffset.UtcNow;

            // Synchronize cancelled/declined status to any linked proposal
            if (req.NewStatus == "Cancelled" || req.NewStatus == "Declined")
            {
                if (booking.ProposalId.HasValue)
                {
                    var p = await _dbContext.Proposals.FirstOrDefaultAsync(x => x.Id == booking.ProposalId.Value, ct);
                    if (p != null)
                    {
                        p.Status = req.NewStatus;
                        p.UpdatedAt = DateTimeOffset.UtcNow;
                    }
                }
                var pByRef = await _dbContext.Proposals.FirstOrDefaultAsync(x => 
                    x.ProposalReference == booking.BookingReference || 
                    x.ProposalReference == booking.BookingReference.Replace("TB-", "PR-"), ct);
                if (pByRef != null)
                {
                    pByRef.Status = req.NewStatus;
                    pByRef.UpdatedAt = DateTimeOffset.UtcNow;
                }
            }

            await _dbContext.SaveChangesAsync(ct);
            return booking;
        }

        // What if the reference was a proposal reference (e.g. PR-1001)?
        if (!string.IsNullOrWhiteSpace(req.BookingReference))
        {
            var proposal = await _dbContext.Proposals.FirstOrDefaultAsync(p => 
                p.ProposalReference == req.BookingReference ||
                p.ProposalReference == req.BookingReference.Replace("TB-", "PR-"), ct);

            if (proposal != null)
            {
                proposal.Status = req.NewStatus;
                proposal.UpdatedAt = DateTimeOffset.UtcNow;

                var linkedB = await _dbContext.Bookings.FirstOrDefaultAsync(b => 
                    b.ProposalId == proposal.Id || 
                    b.BookingReference == proposal.ProposalReference ||
                    b.BookingReference == proposal.ProposalReference.Replace("PR-", "TB-"), ct);
                if (linkedB != null)
                {
                    linkedB.Status = req.NewStatus;
                    linkedB.UpdatedAt = DateTimeOffset.UtcNow;
                }

                await _dbContext.SaveChangesAsync(ct);
                return new BookingEntity
                {
                    Id = proposal.Id,
                    BookingReference = proposal.ProposalReference,
                    CustomerName = proposal.CustomerName,
                    ProviderName = proposal.ProviderName,
                    ServiceTitle = proposal.ServiceTitle,
                    Category = proposal.Category,
                    Location = proposal.Location,
                    Schedule = proposal.PreferredSchedule,
                    Price = proposal.EstimatedRate,
                    RateType = proposal.RateType,
                    Status = proposal.Status
                };
            }
        }

        return null;
    }

    private async Task<string> GenerateOpenAiRationaleAsync(
        JobPlanDetails plan,
        ProviderQuotationDto winner,
        List<ProviderQuotationDto> quotes,
        string apiKey,
        string model,
        CancellationToken ct)
    {
        try
        {
            var systemPrompt = """
                You are TaskBridge AI (Agent 3: Coordination Agent).
                Your job is to provide a concise, professional 2-sentence explanation of why you recommend this specific provider to receive the customer's proposal.
                Highlight:
                1. How their standard hourly rate fits within the customer's budget.
                2. How their availability aligns with the customer's requested timeframe.
                3. Their verified track record, rating, or proximity.
                Be polite, clear, and reassuring.
                """;

            var userContent = $"""
                Job Request: {plan.ServiceTitle} ({plan.Category})
                Customer Budget: {(plan.Budget.HasValue ? $"Rs. {plan.Budget.Value}" : "Flexible")}
                Customer Requested Schedule: {plan.ScheduledDate} {plan.ScheduledTime}
                Recommended Provider: {winner.FullName} (Hourly Rate: Rs. {winner.QuotedPrice}/hr, Preferred Window: {winner.AvailableTime}, Rating: {winner.Rating}★)
                Other providers: {string.Join(", ", quotes.Where(q => q.ProviderId != winner.ProviderId).Select(q => $"{q.FullName}: Rs. {q.QuotedPrice}/hr"))}
                """;

            var requestBody = new
            {
                model = model,
                messages = new object[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userContent }
                },
                max_tokens = 120,
                temperature = 0.3
            };

            var httpRequest = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions")
            {
                Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json")
            };
            httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

            var response = await _httpClient.SendAsync(httpRequest, ct);
            if (!response.IsSuccessStatusCode)
            {
                return GenerateRuleBasedRationale(plan, winner);
            }

            var json = await response.Content.ReadAsStringAsync(ct);
            using var doc = JsonDocument.Parse(json);
            var content = doc.RootElement.GetProperty("choices")[0].GetProperty("message").GetProperty("content").GetString();
            return content?.Trim() ?? GenerateRuleBasedRationale(plan, winner);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "OpenAI rationale generation failed. Falling back to rule-based.");
            return GenerateRuleBasedRationale(plan, winner);
        }
    }

    private string GenerateRuleBasedRationale(JobPlanDetails plan, ProviderQuotationDto winner)
    {
        var budgetPhrase = plan.Budget.HasValue
            ? (winner.QuotedPrice <= plan.Budget.Value
                ? $"fits within your budget"
                : "offers competitive market rates")
            : "offers fair hourly rates";

        return $"{winner.FullName} is recommended based on their rate of Rs. {winner.QuotedPrice:N0}/hr ({budgetPhrase}), verified {winner.Rating:F1}★ rating, and proximity of {winner.DistanceKm:F1} km. You can send your proposed time window for their confirmation.";
    }

    public List<ProviderQuotationDto> GenerateFallbackQuotes(JobPlanDetails plan)
    {
        var basePrice = plan.Budget ?? 4500m;
        var p1Price = Math.Round(basePrice * 0.90m / 100m) * 100m; // Rs. 4,500
        var p2Price = Math.Round(basePrice * 1.20m / 100m) * 100m; // Rs. 6,000

        var isMorning = plan.ScheduledTime.ToLowerInvariant().Contains("morning");
        var time1 = isMorning ? "Tomorrow at 9:30 AM" : "Tomorrow at 4:00 PM";
        var time2 = isMorning ? "Tomorrow at 11:30 AM" : "Tomorrow at 5:30 PM";

        return new List<ProviderQuotationDto>
        {
            new()
            {
                ProviderId = "p-ravindu",
                FullName = "Ravindu Dissanayake",
                Category = plan.Category,
                ProfilePhotoUrl = null,
                Phone = "0771234567",
                QuotedPrice = p1Price > 0 ? p1Price : 4500m,
                AvailableTime = time1,
                DistanceKm = 2.4,
                Rating = 4.8,
                ReviewCount = 12,
                Notes = "Includes complete cleanup, specialized equipment, and disposal.",
                MatchScore = 96
            },
            new()
            {
                ProviderId = "p-kavindu",
                FullName = "Kavindu Alwis",
                Category = plan.Category,
                ProfilePhotoUrl = null,
                Phone = "0719876543",
                QuotedPrice = p2Price > 0 ? p2Price : 6000m,
                AvailableTime = time2,
                DistanceKm = 3.9,
                Rating = 4.9,
                ReviewCount = 18,
                Notes = "Includes certified inspection, high-power equipment, and cleanup.",
                MatchScore = 88
            }
        };
    }
}

