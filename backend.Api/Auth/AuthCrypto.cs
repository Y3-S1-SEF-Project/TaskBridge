using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace TaskBridge.Api.Auth;

public sealed class AuthCrypto(IConfiguration config)
{
    // Normalizes Sri Lankan mobile numbers to Notify.lk's required format.
    public static string Phone(string input)
    {
        var phone = Regex.Replace(input.Trim(), @"[\s()+-]", "");
        if (phone.StartsWith("0")) phone = "94" + phone[1..];
        if (!Regex.IsMatch(phone, @"^947[0-9]{8}$"))
            throw new AuthProblem(400, "Enter a valid Sri Lankan mobile number, such as 0771234567.");
        return phone;
    }

    // Enforces the shared password policy before hashing a password.
    public static void ValidatePassword(string password)
    {
        if (password.Length < 8 || password.Length > 128 || !Regex.IsMatch(password, "[a-zA-Z]") || !Regex.IsMatch(password, "[0-9]"))
            throw new AuthProblem(400, "Use 8–128 characters including a letter and a number.");
    }

    // Creates a cryptographically random six-digit verification code.
    public static string Code() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    // Creates a high-entropy session or password-reset token.
    public static string Token() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

    // Hashes high-entropy bearer tokens before database storage.
    public static string TokenHash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    // Binds the OTP hash to the email with a server-only key.
    public string CodeHash(string email, string code)
    {
        var key = config["Auth:OtpSigningKey"] ?? "c9286c861b2743d4efa54c2ba00ac2095852e5c9ed43e7f5f7f5e062f6993816";
        return Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(key),
            Encoding.UTF8.GetBytes($"{email.ToLowerInvariant()}:{code}")));
    }

    // Compares fixed-length hashes without exposing a timing difference.
    public static bool Matches(string first, string second) => CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(first), Encoding.UTF8.GetBytes(second));
}
