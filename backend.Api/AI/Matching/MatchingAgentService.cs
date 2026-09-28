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