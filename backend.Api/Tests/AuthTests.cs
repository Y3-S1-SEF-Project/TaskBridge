using System.Collections.Concurrent;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Npgsql;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;
using Xunit;

namespace TaskBridge.Api.Tests;

public sealed class AuthTests
{
    // Checks that local and international mobile numbers resolve to one account key.
    [Theory]
    [InlineData("0771234567", "94771234567")]
    [InlineData("+94 77 123 4567", "94771234567")]
    public void NormalizesPhone(string input, string expected) => Assert.Equal(expected, AuthCrypto.Phone(input));

    // Rejects numbers that cannot receive the configured Sri Lankan mobile OTP.
    [Theory]
    [InlineData("0111234567")]
    [InlineData("+14155551234")]
    [InlineData("")]
    public void RejectsInvalidPhone(string input) => Assert.Throws<AuthProblem>(() => AuthCrypto.Phone(input));

    // Verifies that OTP hashes are tied to both the challenge and its purpose.
    [Fact]
    public void OtpHashCannotBeReusedForAnotherPurpose()
    {
        var crypto = Crypto();
        var challenge = new OtpChallenge { Purpose = "login" };
        var hash = crypto.CodeHash(challenge, "123456");
        challenge.Purpose = "reset";
        Assert.False(AuthCrypto.Matches(hash, crypto.CodeHash(challenge, "123456")));
        Assert.DoesNotContain("123456", hash);
    }

    // Exercises registration, replay prevention, and reset revocation against a dedicated database.
    [Fact]
    public async Task RegistrationAndResetAreSingleUse()
    {
        var connection = Environment.GetEnvironmentVariable("TASKBRIDGE_TEST_POSTGRES")
            ?? throw new InvalidOperationException("Set TASKBRIDGE_TEST_POSTGRES to a dedicated database ending in _test.");
        var parsed = new NpgsqlConnectionStringBuilder(connection);
        if (parsed.Database?.EndsWith("_test", StringComparison.Ordinal) != true)
            throw new InvalidOperationException("Tests require a dedicated database ending in _test.");
        var options = new DbContextOptionsBuilder<AuthDbContext>().UseNpgsql(connection).Options;
        await using (var setup = new AuthDbContext(options))
            await setup.Database.ExecuteSqlRawAsync(await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "001_auth.sql")));
        var phone = "947" + RandomNumberGenerator.GetInt32(0, 100_000_000).ToString("D8");
        var sender = new RecordingSender();
        var crypto = Crypto();

        // Gives each simulated HTTP request its own database context.
        async Task<T> Request<T>(Func<AuthService, Task<T>> action)
        {
            await using var db = new AuthDbContext(options);
            return await action(new AuthService(db, new PasswordHasher<AppUser>(), crypto, sender));
        }

        try
        {
            var registration = await Request(s => s.Register(new("Test Account", phone, "InitialPassword1"), default));
            var code = sender.Codes[phone];
            await using (var check = new AuthDbContext(options)) Assert.False(await check.Users.AnyAsync(x => x.Phone == phone));
            var wrongCode = code == "000000" ? "000001" : "000000";
            await Assert.ThrowsAsync<AuthProblem>(() => Request(s => s.Verify(new(registration.ChallengeId, wrongCode), default)));
            var signedIn = await Request(s => s.Verify(new(registration.ChallengeId, code), default));
            Assert.NotNull(signedIn.Session);
            await Assert.ThrowsAsync<AuthProblem>(() => Request(s => s.Verify(new(registration.ChallengeId, code), default)));
            await using (var wait = new AuthDbContext(options))
                await wait.Challenges.Where(x => x.Phone == phone).ExecuteUpdateAsync(s => s.SetProperty(x => x.ResendAt, DateTimeOffset.UtcNow.AddMinutes(-1)));
            var recovery = await Request(s => s.Forgot(new(phone), default));
            var verified = await Request(s => s.Verify(new(recovery.ChallengeId, sender.Codes[phone]), default));
            Assert.Null(verified.Session);
            Assert.NotNull(verified.ResetToken);
            var reset = new ResetRequest(recovery.ChallengeId, verified.ResetToken!, "ReplacementPassword2");
            await Request(async s => { await s.Reset(reset, default); return true; });
            await Assert.ThrowsAsync<AuthProblem>(() => Request(async s => { await s.Reset(reset, default); return true; }));
            await using var inspect = new AuthDbContext(options);
            var user = await inspect.Users.SingleAsync(x => x.Phone == phone);
            Assert.Empty(await inspect.Sessions.Where(x => x.UserId == user.Id).ToListAsync());
            Assert.Equal(PasswordVerificationResult.Failed, new PasswordHasher<AppUser>().VerifyHashedPassword(user, user.PasswordHash, "InitialPassword1"));
            Assert.NotEqual(PasswordVerificationResult.Failed, new PasswordHasher<AppUser>().VerifyHashedPassword(user, user.PasswordHash, "ReplacementPassword2"));
        }
        finally
        {
            await using var cleanup = new AuthDbContext(options);
            await cleanup.Challenges.Where(x => x.Phone == phone).ExecuteDeleteAsync();
            await cleanup.Users.Where(x => x.Phone == phone).ExecuteDeleteAsync();
        }
    }

    // Creates a test-only signing key with no production secrets.
    private static AuthCrypto Crypto() => new(new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?> { ["Auth:OtpSigningKey"] = new string('t', 64) }).Build());

    private sealed class RecordingSender : IOtpSender
    {
        public ConcurrentDictionary<string, string> Codes { get; } = new();

        // Captures test codes in memory without calling Notify.lk.
        public Task SendAsync(string phone, string code, CancellationToken ct) { Codes[phone] = code; return Task.CompletedTask; }
    }
}
