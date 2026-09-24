using System.Net;
using System.Net.Mail;

namespace TaskBridge.Api.Auth;

public interface IEmailOtpSender
{
    Task SendOtpAsync(string toEmail, string fullName, string code, CancellationToken ct = default);
}

public sealed class EmailOtpSender(IConfiguration config, ILogger<EmailOtpSender> logger) : IEmailOtpSender
{
    public async Task SendOtpAsync(string toEmail, string fullName, string code, CancellationToken ct = default)
    {
        var host = config["Smtp:Host"] ?? "smtp.gmail.com";
        var port = int.TryParse(config["Smtp:Port"], out var p) ? p : 587;
        var senderEmail = config["Smtp:SenderEmail"] ?? "taskbridge.com@gmail.com";
        var senderName = config["Smtp:SenderName"] ?? "TaskBridge";
        var password = config["Smtp:Password"] ?? "vjis wzks jqsw qkmh";
        var enableSsl = !bool.TryParse(config["Smtp:EnableSsl"], out var ssl) || ssl;

        using var client = new SmtpClient(host, port)
        {
            Credentials = new NetworkCredential(senderEmail, password),
            EnableSsl = enableSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = 15000
        };

        using var message = new MailMessage
        {
            From = new MailAddress(senderEmail, senderName),
            Subject = $"{code} is your TaskBridge verification code",
            IsBodyHtml = true,
            Body = $@"
<!DOCTYPE html>
<html>
<head>
  <meta charset='utf-8'>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F7F9F8; margin: 0; padding: 24px; }}
    .container {{ max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #E2E8E4; padding: 32px; }}
    .header {{ font-size: 20px; font-weight: 700; color: #17211B; margin-bottom: 8px; }}
    .subtext {{ font-size: 15px; color: #66736B; line-height: 1.5; margin-bottom: 24px; }}
    .otp-card {{ background: #E8F5EE; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 24px; }}
    .otp-code {{ font-size: 32px; font-weight: 800; letter-spacing: 6px; color: #256B4A; font-family: monospace; }}
    .footer {{ font-size: 13px; color: #8F9E95; text-align: center; margin-top: 24px; }}
  </style>
</head>
<body>
  <div class='container'>
    <div class='header'>TaskBridge Verification</div>
    <div class='subtext'>Hello {(string.IsNullOrWhiteSpace(fullName) ? "there" : fullName)},<br/>Use the 6-digit verification code below to complete your registration:</div>
    <div class='otp-card'>
      <div class='otp-code'>{code}</div>
    </div>
    <div class='subtext'>This code is valid for 10 minutes. If you did not request this code, please ignore this email.</div>
    <div class='footer'>© {DateTime.UtcNow.Year} TaskBridge · Your trusted service bridge</div>
  </div>
</body>
</html>"
        };

        message.To.Add(new MailAddress(toEmail, fullName));

        try
        {
            await client.SendMailAsync(message, ct);
            logger.LogInformation("Verification email successfully sent to {Email}", toEmail);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send verification email to {Email}", toEmail);
            throw new AuthProblem(503, "We could not send the verification email. Please check your email address and try again.");
        }
    }
}
