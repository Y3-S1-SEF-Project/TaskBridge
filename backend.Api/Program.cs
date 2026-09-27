using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Auth;
using TaskBridge.Api.Data;

var builder = WebApplication.CreateBuilder(args);

// Loads ignored local credentials in development; environment variables take priority.
if (builder.Environment.IsDevelopment()) builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false);
builder.Configuration.AddEnvironmentVariables();
builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<AuthErrorHandler>();
builder.Services.AddDbContext<AuthDbContext>(options => options.UseNpgsql(
    builder.Configuration.GetConnectionString("TaskBridge") ?? "Host=localhost;Database=taskbridge;Username=postgres"));
builder.Services.AddScoped<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.Configure<PasswordHasherOptions>(options => options.IterationCount = 210_000);
builder.Services.AddScoped<AuthCrypto>();
builder.Services.AddSingleton<ChatCrypto>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<IEmailOtpSender, EmailOtpSender>();
builder.Services.AddSingleton<IProfileImageService, R2ImageService>();
builder.Services.AddSignalR();
builder.Services.AddHttpClient<IOtpSender, NotifySmsSender>(client => client.Timeout = TimeSpan.FromSeconds(10));
builder.Services.AddHttpClient<backend.Api.AI.PlanningAgentService>(client => client.Timeout = TimeSpan.FromSeconds(25));
builder.Services.AddHttpClient<backend.Api.AI.MatchingAgentService>(client => client.Timeout = TimeSpan.FromSeconds(25));
builder.Services.AddHttpClient<backend.Api.AI.CoordinationAgentService>(client => client.Timeout = TimeSpan.FromSeconds(25));
builder.Services.AddHttpClient<backend.Api.AI.ReviewAgentService>(client => client.Timeout = TimeSpan.FromSeconds(45));
builder.Services.AddAuthentication("Session").AddScheme<AuthenticationSchemeOptions, SessionAuthenticationHandler>("Session", null);
builder.Services.AddAuthorization();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    // Limits authentication traffic by the actual remote IP address.
    options.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 40, Window = TimeSpan.FromMinutes(10), QueueLimit = 0 }));
});

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Ensures the single users table schema is initialized
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AuthDbContext>();
    await db.EnsureSchemaAsync();
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseExceptionHandler();
if (!app.Environment.IsDevelopment()) app.UseHttpsRedirection();