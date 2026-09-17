using System.Text.Json;

namespace TaskBridge.Api.Auth;

public interface IOtpSender
{
    Task SendAsync(string phone, string code, CancellationToken cancellationToken);
}

public sealed class NotifySmsSender(
    HttpClient client,
    IConfiguration config,
    IWebHostEnvironment env,
    ILogger<NotifySmsSender> logger) : IOtpSender
{
    // Sends a branded OTP using Notify.lk without putting credentials in a URL.
    public async Task SendAsync(string phone, string code, CancellationToken cancellationToken)
    {
        var sender = config["Notify:SenderId"];
        var key = config["Notify:ApiKey"];
        var userId = config["Notify:UserId"];

        // In Development mode, if SenderId is unverified, blank, or NotifyDEMO, log the OTP code to terminal console.
        if (env.IsDevelopment() && (string.IsNullOrWhiteSpace(sender) || sender.Equals("NotifyDEMO", StringComparison.OrdinalIgnoreCase) || sender.Equals("DEV", StringComparison.OrdinalIgnoreCase)))
        {
            logger.LogWarning("\n==================================================\n[DEV MOCK OTP] Code for {Phone}: {Code}\n==================================================\n", phone, code);
            return;
        }

        if (string.IsNullOrWhiteSpace(sender) || sender.Equals("NotifyDEMO", StringComparison.OrdinalIgnoreCase)
            || string.IsNullOrWhiteSpace(key) || string.IsNullOrWhiteSpace(userId))
            throw new AuthProblem(503, "SMS verification is not configured. Contact TaskBridge support.");

        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["user_id"] = userId, ["api_key"] = key, ["sender_id"] = sender,
            ["to"] = phone, ["message"] = $"Your TaskBridge verification code is {code}. It expires in 5 minutes. Do not share this code."
        });
        try
        {
            using var response = await client.PostAsync("https://app.notify.lk/api/v1/send", content, cancellationToken);
            if (!response.IsSuccessStatusCode) throw new AuthProblem(503, "We could not send the verification code. Please try again later.");
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
            if (!json.RootElement.TryGetProperty("status", out var status) || status.GetString() != "success")
                throw new AuthProblem(503, "We could not send the verification code. Please try again later.");
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            throw new AuthProblem(503, "The SMS service is unavailable. Please try again later.");
        }
    }
}

