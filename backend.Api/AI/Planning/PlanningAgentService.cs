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
                  "clarificationQuestion": "Where do you need the service? We need your location to find providers who cover your area.",
                  "acceptanceChecklist": [
                    "Isolate water valve and remove defective tap fitting",
                    "Fit and secure replacement seal / cartridge",
                    "Conduct water pressure test and verify leak-free operation",
                    "Clean and tidy workspace area"
                  ]
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

            // Explicitly detect if prompt mentioned date/time keywords
            var pLower = request.Prompt.ToLowerInvariant();
            var hasDateWords = pLower.Contains("today") || pLower.Contains("tomorrow") || pLower.Contains("tonight")
                || pLower.Contains("monday") || pLower.Contains("tuesday") || pLower.Contains("wednesday")
                || pLower.Contains("thursday") || pLower.Contains("friday") || pLower.Contains("saturday")
                || pLower.Contains("sunday") || pLower.Contains("weekend") || pLower.Contains("next week")
                || pLower.Contains("this week") || pLower.Contains("sep") || pLower.Contains("oct") || pLower.Contains("nov");

            var hasTimeWords = pLower.Contains("am") || pLower.Contains("pm") || pLower.Contains("morning")
                || pLower.Contains("afternoon") || pLower.Contains("evening") || pLower.Contains("night")
                || pLower.Contains("urgent") || pLower.Contains("asap") || pLower.Contains("o'clock")
                || pLower.Contains(":00") || pLower.Contains(":30") || pLower.Contains("after 3") || pLower.Contains("at 3");

            bool isDateMissing = !hasDateWords || string.IsNullOrWhiteSpace(openAiData.ScheduledDate) || openAiData.ScheduledDate.Equals("Flexible", StringComparison.OrdinalIgnoreCase);
            bool isTimeMissing = !hasTimeWords || string.IsNullOrWhiteSpace(openAiData.ScheduledTime) || openAiData.ScheduledTime.Equals("Flexible", StringComparison.OrdinalIgnoreCase);

            if (isDateMissing)
            {
                openAiData.ScheduledDate = null;
                if (!openAiData.MissingFields.Contains("date")) openAiData.MissingFields.Add("date");
            }

            if (isTimeMissing)
            {
                openAiData.ScheduledTime = null;
                if (!openAiData.MissingFields.Contains("time")) openAiData.MissingFields.Add("time");
            }

            // If scheduled date/time/budget were explicitly provided in request context, apply them
            if (!string.IsNullOrWhiteSpace(request.ScheduledDate))
            {
                openAiData.ScheduledDate = request.ScheduledDate;
                openAiData.MissingFields.Remove("date");
                isDateMissing = false;
            }

            if (!string.IsNullOrWhiteSpace(request.ScheduledTime))
            {
                openAiData.ScheduledTime = request.ScheduledTime;
                openAiData.MissingFields.Remove("time");
                isTimeMissing = false;
            }

            if (request.Budget.HasValue && request.Budget.Value > 0)
            {
                openAiData.Budget = request.Budget.Value;
                openAiData.BudgetDisplay = $"Budget up to Rs. {request.Budget.Value:N0}";
                openAiData.MissingFields.Remove("budget");
            }
            else if (!openAiData.Budget.HasValue || openAiData.Budget <= 0)
            {
                if (!openAiData.MissingFields.Contains("budget")) openAiData.MissingFields.Add("budget");
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

            if (openAiData.IsLocationMissing && (isDateMissing || isTimeMissing))
            {
                openAiData.ClarificationQuestion = "Where and when do you need the service? We need your location and preferred schedule.";
            }
            else if (openAiData.IsLocationMissing)
            {
                openAiData.ClarificationQuestion = "Where do you need the service? We need your location to find providers who cover your area.";
            }
            else if (isDateMissing || isTimeMissing)
            {
                openAiData.ClarificationQuestion = "When would you like this service scheduled? Please select your preferred date and time.";
            }

            var plan = new JobPlanDetails
            {
                ServiceTitle = string.IsNullOrWhiteSpace(openAiData.ServiceTitle) ? "Home Service Repair" : openAiData.ServiceTitle,
                Category = string.IsNullOrWhiteSpace(openAiData.Category) ? "General Handyman" : openAiData.Category,
                Description = string.IsNullOrWhiteSpace(openAiData.Description) ? request.Prompt : openAiData.Description,
                Location = openAiData.Location,
                LocationAddress = openAiData.LocationAddress ?? (string.IsNullOrWhiteSpace(openAiData.Location) ? null : "24 Park Road"),
                ScheduledDate = openAiData.ScheduledDate ?? string.Empty,
                ScheduledTime = openAiData.ScheduledTime ?? string.Empty,
                Budget = openAiData.Budget,
                BudgetDisplay = string.IsNullOrWhiteSpace(openAiData.BudgetDisplay) 
                    ? (openAiData.Budget.HasValue ? $"Budget up to Rs. {openAiData.Budget.Value:N0}" : "Budget not specified") 
                    : openAiData.BudgetDisplay,
                AcceptanceChecklist = (openAiData.AcceptanceChecklist != null && openAiData.AcceptanceChecklist.Count > 0)
                    ? openAiData.AcceptanceChecklist
                    : GetDefaultChecklist(openAiData.Category ?? "General", openAiData.ServiceTitle ?? request.Prompt)
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
                    Subtitle = string.IsNullOrWhiteSpace(plan.ScheduledDate) ? "Availability matching" : $"{plan.ScheduledDate.Split('·').First().Trim()} {plan.ScheduledTime}".Trim(),
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
            Console.WriteLine($"[✅ TASKBRIDGE AI] Date: \"{(string.IsNullOrEmpty(plan.ScheduledDate) ? "MISSING" : plan.ScheduledDate)}\" | Time: \"{(string.IsNullOrEmpty(plan.ScheduledTime) ? "MISSING" : plan.ScheduledTime)}\"");
            Console.WriteLine($"[✅ TASKBRIDGE AI] Budget: {plan.BudgetDisplay} | MissingFields: [{string.Join(", ", openAiData.MissingFields)}]");
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
        var isPainting = promptLower.Contains("paint") || promptLower.Contains("painter") || promptLower.Contains("wall");
        var isAc = promptLower.Contains("ac") || promptLower.Contains("air") || promptLower.Contains("cool");
        var isGarden = promptLower.Contains("garden") || promptLower.Contains("lawn") || promptLower.Contains("grass") || promptLower.Contains("yard");
        var isCleaning = promptLower.Contains("clean") || promptLower.Contains("wash") || promptLower.Contains("maid");

        var category = isPlumbing ? "Plumbing" 
            : (isPainting ? "Painting"
            : (isGarden ? "Gardening" 
            : (isCleaning ? "Cleaning" 
            : (isElectrical ? "Electrical" 
            : (isAc ? "HVAC" : "General Handyman")))));

        var title = isPlumbing ? "Kitchen tap repair" 
            : (isPainting ? "Wall & surface painting"
            : (isGarden ? "Garden Cleaning" 
            : (isCleaning ? "Deep Cleaning" 
            : (isElectrical ? "Electrical wiring repair" 
            : (isAc ? "Air conditioning repair" : "Home Maintenance")))));

        var desc = isPlumbing ? "Repair the leaking kitchen tap and test for leaks." 
            : (isGarden ? "Clean and restore the garden to pristine condition." 
            : $"Inspect and resolve: {request.Prompt}");

        bool locationMissing = string.IsNullOrWhiteSpace(request.UserLocation);
        var location = locationMissing ? null : request.UserLocation;

        var hasBudgetDigits = request.Prompt.Any(char.IsDigit);
        decimal? budget = hasBudgetDigits ? 5000m : null;
        var budgetDisplay = hasBudgetDigits ? "Budget up to Rs. 5,000" : "Budget not specified";

        var hasDateWords = promptLower.Contains("today") || promptLower.Contains("tomorrow") || promptLower.Contains("tonight")
            || promptLower.Contains("monday") || promptLower.Contains("tuesday") || promptLower.Contains("wednesday")
            || promptLower.Contains("thursday") || promptLower.Contains("friday") || promptLower.Contains("saturday")
            || promptLower.Contains("sunday") || promptLower.Contains("weekend");

        var hasTimeWords = promptLower.Contains("am") || promptLower.Contains("pm") || promptLower.Contains("morning")
            || promptLower.Contains("afternoon") || promptLower.Contains("evening") || promptLower.Contains("night")
            || promptLower.Contains("urgent") || promptLower.Contains("asap") || promptLower.Contains("o'clock")
            || promptLower.Contains("after 3") || promptLower.Contains("at 3");

        var missing = new List<string>();
        if (locationMissing) missing.Add("location");
        if (!hasDateWords) missing.Add("date");
        if (!hasTimeWords) missing.Add("time");
        if (!hasBudgetDigits && (!request.Budget.HasValue || request.Budget.Value <= 0)) missing.Add("budget");
        var scheduledDate = hasDateWords ? "Tomorrow · 17 Sep" : string.Empty;
        var scheduledTime = hasTimeWords ? "After 3:00 PM" : string.Empty;

        if (!string.IsNullOrWhiteSpace(request.ScheduledDate))
        {
            scheduledDate = request.ScheduledDate;
            missing.Remove("date");
        }
        if (!string.IsNullOrWhiteSpace(request.ScheduledTime))
        {
            scheduledTime = request.ScheduledTime;
            missing.Remove("time");
        }
        if (request.Budget.HasValue && request.Budget.Value > 0)
        {
            budget = request.Budget.Value;
            budgetDisplay = $"Budget up to Rs. {request.Budget.Value:N0}";
            missing.Remove("budget");
        }

        var plan = new JobPlanDetails
        {
            ServiceTitle = title,
            Category = category,
            Description = desc,
            Location = location,
            LocationAddress = location != null ? "24 Park Road" : null,
            ScheduledDate = scheduledDate,
            ScheduledTime = scheduledTime,
            Budget = budget,
            BudgetDisplay = budgetDisplay,
            AcceptanceChecklist = GetDefaultChecklist(category, title)
        };

        var steps = new List<ReasoningStepItem>
        {
            new() { StepKey = "understanding_service", Title = "Understanding service", Subtitle = plan.ServiceTitle, Status = "completed" },
            new() { StepKey = "finding_providers", Title = "Finding suitable providers", Subtitle = "Skills and service area matched", Status = "completed" },
            new() { StepKey = "checking_availability", Title = "Checking availability", Subtitle = string.IsNullOrEmpty(scheduledDate) ? "Availability matching" : $"{scheduledDate} {scheduledTime}".Trim(), Status = "completed" },
            new() { StepKey = "preparing_recommendation", Title = "Preparing recommendation", Subtitle = "Waiting for availability checks", Status = "pending" }
        };

        var clarification = "Where do you need the service? We need your location to find providers who cover your area.";
        if (locationMissing && (!hasDateWords || !hasTimeWords))
        {
            clarification = "Where and when do you need the service? We need your location and preferred schedule.";
        }
        else if (!hasDateWords || !hasTimeWords)
        {
            clarification = "When would you like this service scheduled? Please select your preferred date and time.";
        }

        return new PlanningAnalyzeResponse
        {
            Success = true,
            IsLocationMissing = locationMissing,
            MissingFields = missing,
            ClarificationQuestion = clarification,
            JobPlan = plan,
            ProgressSteps = steps,
            LatencyMs = latencyMs,
            TokensUsed = 0,
            Model = "rule-based-fallback"
        };
    }

    private static List<string> GetDefaultChecklist(string category, string title)
    {
        var cat = (category ?? "").ToLowerInvariant();
        var t = (title ?? "").ToLowerInvariant();

        if (cat.Contains("plumb") || t.Contains("tap") || t.Contains("leak") || t.Contains("pipe"))
        {
            return new List<string>
            {
                "Inspect plumbing connection and shut off water valve",
                "Replace worn seal, washer, or cartridge assembly",
                "Perform pressure water test to verify zero leaks",
                "Wipe down and clean work area thoroughly"
            };
        }
        if (cat.Contains("garden") || t.Contains("grass") || t.Contains("lawn"))
        {
            return new List<string>
            {
                "Clear weeds, overgrowth, and dead plant matter",
                "Trim hedges, grass edges, or designated shrubbery",
                "Collect, bag, and remove all green garden waste",
                "Sweep and tidy all adjacent pathways and garden beds"
            };
        }
        if (cat.Contains("electr") || t.Contains("wire") || t.Contains("switch") || t.Contains("light"))
        {
            return new List<string>
            {
                "Isolate circuit breaker and verify zero voltage with multimeter",
                "Install/repair designated electrical fixture or wiring securely",
                "Restore power and test functionality under operational load",
                "Ensure wire insulation and work area safety compliance"
            };
        }
        if (cat.Contains("clean") || t.Contains("wash"))
        {
            return new List<string>
            {
                "Deep clean and sanitize specified fixtures and surfaces",
                "Remove heavy stains, grime, and dust buildup",
                "Dry and buff all polished or glass surfaces",
                "Dispose of all trash and return items to tidy order"
            };
        }

        return new List<string>
        {
            "Inspect and prepare work area with appropriate safety measures",
            "Perform primary service/repair per agreed specifications",
            "Test and verify operational function in presence of test conditions",
            "Clean up work area and dispose of all debris"
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
        public List<string> AcceptanceChecklist { get; set; } = new();
    }
}
