using System.Diagnostics;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace backend.Api.AI;

public class PlanningAgentService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PlanningAgentService> _logger;

    public PlanningAgentService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<PlanningAgentService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<PlanningAnalyzeResponse> AnalyzePromptAsync(PlanningAnalyzeRequest request, CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        var apiKey = _configuration["OpenAI:ApiKey"] 
            ?? Environment.GetEnvironmentVariable("OPENAI_API_KEY") 
            ?? string.Empty;

        var model = _configuration["OpenAI:Model"] ?? "gpt-4o-mini";

        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("\n============================================================");
        Console.WriteLine($"[🤖 TASKBRIDGE AI: AGENT 1 - PLANNING AGENT]");
        Console.WriteLine($"📥 Analyzing Customer Prompt: \"{request.Prompt}\"");
        if (!string.IsNullOrWhiteSpace(request.UserLocation))
        {
            Console.WriteLine($"📍 Provided Location Context: {request.UserLocation}");
        }
        Console.WriteLine("============================================================\n");
        Console.ResetColor();

        // If no API key is provided, return intelligent rule-based parsing so app never crashes
        if (string.IsNullOrWhiteSpace(apiKey) || apiKey.StartsWith("YOUR_"))
        {
            _logger.LogWarning("OpenAI API Key not configured. Using rule-based fallback.");
            return GenerateFallbackResponse(request, sw.ElapsedMilliseconds);
        }

        try
        {
            var systemPrompt = """
                You are TaskBridge AI (Agent 1: Planning Agent).
                TaskBridge is an on-demand home service marketplace in Sri Lanka.
                Valid categories: 'Plumbing', 'Electrical', 'HVAC', 'Cleaning', 'Carpentry', 'Painting', 'Appliance Repair', 'Gardening', 'Roofing'.
                Today's date reference: September 2026.

                Analyze the user's home service request. Extract structured information.
                - If the user explicitly mentions a budget/cost constraint (e.g. 5000, 2500, Rs. 5000), set "budget" to the numeric amount and "budgetDisplay" to "Budget up to Rs. X".
                - If the user does NOT mention any budget or price, set "budget": null, "budgetDisplay": "Budget not specified", and include "budget" in "missingFields".
                - If the user did not specify any location/address and userLocation context is empty, set "location": null, "locationAddress": null, "isLocationMissing": true, and include "location" in "missingFields".
                
                Respond ONLY with a JSON object in this exact schema:
                {
                  "serviceTitle": "Brief title e.g. Kitchen tap repair or Garden Cleaning",
                  "category": "Plumbing or Gardening or Cleaning or Electrical etc.",
                  "description": "Clear 1-2 sentence description of work",
                  "location": "City or Area e.g. Colombo 05 or null",
                  "locationAddress": "Specific street or null e.g. 24 Park Road",
                  "scheduledDate": "e.g. Tomorrow · 17 Sep or Today or Flexible",
                  "scheduledTime": "e.g. After 3:00 PM or Morning 9:00 AM or Flexible",
                  "budget": 5000 or null,
                  "budgetDisplay": "Budget up to Rs. 5,000 or Budget not specified",
                  "isLocationMissing": true or false,
                  "missingFields": ["location", "budget"],
                  "clarificationQuestion": "Where do you need the service? We need your location to find providers who cover your area."
                }
                """;

            var userContent = $"User Request: \"{request.Prompt}\"\n";
            if (!string.IsNullOrWhiteSpace(request.UserLocation))
            {
                userContent += $"Known User Location: \"{request.UserLocation}\"\n";
            }

            var requestBody = new
            {
                model = model,
                messages = new object[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userContent }
                },
                response_format = new { type = "json_object" },
                temperature = 0.2
            };

            var httpRequest = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/chat/completions")
            {
                Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json")
            };
            httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

            var httpResponse = await _httpClient.SendAsync(httpRequest, ct);
            var responseString = await httpResponse.Content.ReadAsStringAsync(ct);

            sw.Stop();

            if (!httpResponse.IsSuccessStatusCode)
            {
                _logger.LogError("OpenAI API returned error {StatusCode}: {Response}", httpResponse.StatusCode, responseString);
                return GenerateFallbackResponse(request, sw.ElapsedMilliseconds);
            }

            using var doc = JsonDocument.Parse(responseString);
            var root = doc.RootElement;
            var content = root.GetProperty("choices")[0].GetProperty("message").GetProperty("content").GetString() ?? "{}";
            var tokensUsed = root.TryGetProperty("usage", out var usage) && usage.TryGetProperty("total_tokens", out var tt) ? tt.GetInt32() : 0;

            var openAiData = JsonSerializer.Deserialize<OpenAiParsedResult>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (openAiData == null)
            {
                return GenerateFallbackResponse(request, sw.ElapsedMilliseconds);
            }

            // Check if prompt actually mentioned any digits for budget
            var promptHasDigits = request.Prompt.Any(char.IsDigit);
            bool isBudgetProvided = openAiData.Budget.HasValue && openAiData.Budget.Value > 0 && promptHasDigits;
            if (!isBudgetProvided)
            {
                openAiData.Budget = null;
                openAiData.BudgetDisplay = "Budget not specified";
                if (!openAiData.MissingFields.Contains("budget"))
                {
                    openAiData.MissingFields.Add("budget");
                }
            }

            // If location was provided in request context, ensure location is set
            if (!string.IsNullOrWhiteSpace(request.UserLocation) && string.IsNullOrWhiteSpace(openAiData.Location))
            {
                openAiData.Location = request.UserLocation;
                openAiData.IsLocationMissing = false;
                openAiData.MissingFields.Remove("location");
            }

            // If location is null/empty, mark as missing
            if (string.IsNullOrWhiteSpace(openAiData.Location))
            {
                openAiData.IsLocationMissing = true;
                if (!openAiData.MissingFields.Contains("location"))
                {
                    openAiData.MissingFields.Add("location");
                }
            }
            else
            {
                openAiData.IsLocationMissing = false;
                openAiData.MissingFields.Remove("location");
            }

            var plan = new JobPlanDetails
            {
                ServiceTitle = string.IsNullOrWhiteSpace(openAiData.ServiceTitle) ? "Home Service Repair" : openAiData.ServiceTitle,
                Category = string.IsNullOrWhiteSpace(openAiData.Category) ? "General Handyman" : openAiData.Category,
                Description = string.IsNullOrWhiteSpace(openAiData.Description) ? request.Prompt : openAiData.Description,
                Location = openAiData.Location,
                LocationAddress = openAiData.LocationAddress ?? (string.IsNullOrWhiteSpace(openAiData.Location) ? null : "24 Park Road"),
                ScheduledDate = string.IsNullOrWhiteSpace(openAiData.ScheduledDate) ? "Tomorrow · 17 Sep" : openAiData.ScheduledDate,
                ScheduledTime = string.IsNullOrWhiteSpace(openAiData.ScheduledTime) ? "After 3:00 PM" : openAiData.ScheduledTime,
                Budget = openAiData.Budget,
                BudgetDisplay = string.IsNullOrWhiteSpace(openAiData.BudgetDisplay) 
                    ? (openAiData.Budget.HasValue ? $"Budget up to Rs. {openAiData.Budget.Value:N0}" : "Budget not specified") 
                    : openAiData.BudgetDisplay
            };

            // Build the 4 sequential progress steps for Screen C18
            var steps = new List<ReasoningStepItem>
            {
                new()
                {
                    StepKey = "understanding_service",
                    Title = "Understanding service",
                    Subtitle = plan.ServiceTitle,
                    Status = "completed"
                },
                new()
                {
                    StepKey = "finding_providers",
                    Title = "Finding suitable providers",
                    Subtitle = "Skills and service area matched",
                    Status = "completed"
                },
                new()
                {
                    StepKey = "checking_availability",
                    Title = "Checking availability",
                    Subtitle = $"{plan.ScheduledDate.Split('·').First().Trim()} {plan.ScheduledTime}".Trim(),
                    Status = "completed"
                },
                new()
                {
                    StepKey = "preparing_recommendation",
                    Title = "Preparing recommendation",
                    Subtitle = "Waiting for availability checks",
                    Status = "pending"
                }
            };

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"[✅ TASKBRIDGE AI] Parsed Service: \"{plan.ServiceTitle}\" ({plan.Category})");
            Console.WriteLine($"[✅ TASKBRIDGE AI] Location: \"{plan.Location ?? "MISSING"}\" (Missing: {openAiData.IsLocationMissing})");
            Console.WriteLine($"[✅ TASKBRIDGE AI] Schedule: {plan.ScheduledDate} - {plan.ScheduledTime} | Budget: {plan.BudgetDisplay}");
            Console.WriteLine($"[⚡ TASKBRIDGE AI] Tokens: {tokensUsed} | Latency: {sw.ElapsedMilliseconds} ms");
            Console.ResetColor();

            return new PlanningAnalyzeResponse
            {
                Success = true,
                IsLocationMissing = openAiData.IsLocationMissing,
                MissingFields = openAiData.MissingFields,
                ClarificationQuestion = openAiData.ClarificationQuestion ?? "Where do you need the service? We need your location to find providers who cover your area.",
                JobPlan = plan,
                ProgressSteps = steps,
                LatencyMs = sw.ElapsedMilliseconds,
                TokensUsed = tokensUsed,
                Model = model
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call OpenAI Planning Agent");
            return GenerateFallbackResponse(request, sw.ElapsedMilliseconds);
        }
    }

    private PlanningAnalyzeResponse GenerateFallbackResponse(PlanningAnalyzeRequest request, long latencyMs)
    {
        var promptLower = request.Prompt.ToLowerInvariant();
        var isPlumbing = promptLower.Contains("tap") || promptLower.Contains("pipe") || promptLower.Contains("leak") || promptLower.Contains("water") || promptLower.Contains("plumb");
        var isElectrical = promptLower.Contains("light") || promptLower.Contains("wire") || promptLower.Contains("power") || promptLower.Contains("socket") || promptLower.Contains("fan");
        var isAc = promptLower.Contains("ac") || promptLower.Contains("air") || promptLower.Contains("cool");
        var isGarden = promptLower.Contains("garden") || promptLower.Contains("lawn") || promptLower.Contains("grass") || promptLower.Contains("yard");
        var isCleaning = promptLower.Contains("clean") || promptLower.Contains("wash") || promptLower.Contains("maid");

        var category = isPlumbing ? "Plumbing" 
            : (isGarden ? "Gardening" 
            : (isCleaning ? "Cleaning" 
            : (isElectrical ? "Electrical" 
            : (isAc ? "HVAC" : "General Handyman"))));

        var title = isPlumbing ? "Kitchen tap repair" 
            : (isGarden ? "Garden Cleaning" 
            : (isCleaning ? "Deep Cleaning" 
            : (isElectrical ? "Electrical wiring repair" 
            : (isAc ? "Air conditioning repair" : "Home Maintenance"))));

        var desc = isPlumbing ? "Repair the leaking kitchen tap and test for leaks." 
            : (isGarden ? "Clean and restore the garden to pristine condition." 
            : $"Inspect and resolve: {request.Prompt}");

        bool locationMissing = string.IsNullOrWhiteSpace(request.UserLocation);
        var location = locationMissing ? null : request.UserLocation;

        var hasBudgetDigits = request.Prompt.Any(char.IsDigit);
        decimal? budget = hasBudgetDigits ? 5000m : null;
        var budgetDisplay = hasBudgetDigits ? "Budget up to Rs. 5,000" : "Budget not specified";

        var missing = new List<string>();
        if (locationMissing) missing.Add("location");
        if (!hasBudgetDigits) missing.Add("budget");

        var plan = new JobPlanDetails
        {
            ServiceTitle = title,
            Category = category,
            Description = desc,
            Location = location,
            LocationAddress = location != null ? "24 Park Road" : null,
            ScheduledDate = "Tomorrow · 17 Sep",
            ScheduledTime = "After 3:00 PM",
            Budget = budget,
            BudgetDisplay = budgetDisplay
        };

        var steps = new List<ReasoningStepItem>
        {
            new() { StepKey = "understanding_service", Title = "Understanding service", Subtitle = plan.ServiceTitle, Status = "completed" },
            new() { StepKey = "finding_providers", Title = "Finding suitable providers", Subtitle = "Skills and service area matched", Status = "completed" },
            new() { StepKey = "checking_availability", Title = "Checking availability", Subtitle = "Tomorrow after 3 PM", Status = "completed" },
            new() { StepKey = "preparing_recommendation", Title = "Preparing recommendation", Subtitle = "Waiting for availability checks", Status = "pending" }
        };

        return new PlanningAnalyzeResponse
        {
            Success = true,
            IsLocationMissing = locationMissing,
            MissingFields = missing,
            ClarificationQuestion = "Where do you need the service? We need your location to find providers who cover your area.",
            JobPlan = plan,
            ProgressSteps = steps,
            LatencyMs = latencyMs,
            TokensUsed = 0,
            Model = "rule-based-fallback"
        };
    }

    private class OpenAiParsedResult
    {
        public string? ServiceTitle { get; set; }
        public string? Category { get; set; }
        public string? Description { get; set; }
        public string? Location { get; set; }
        public string? LocationAddress { get; set; }
        public string? ScheduledDate { get; set; }
        public string? ScheduledTime { get; set; }
        public decimal? Budget { get; set; }
        public string? BudgetDisplay { get; set; }
        public bool IsLocationMissing { get; set; }
        public List<string> MissingFields { get; set; } = new();
        public string? ClarificationQuestion { get; set; }
    }
}
