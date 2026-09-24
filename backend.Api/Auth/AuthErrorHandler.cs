using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace TaskBridge.Api.Auth;

public sealed class AuthErrorHandler : IExceptionHandler
{
    // Returns safe API errors without leaking secrets, SQL, or provider responses.
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken ct)
    {
        var status = exception switch { AuthProblem p => p.Status, NpgsqlException or DbUpdateException => 503, _ => 500 };
        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = status, Title = "TaskBridge authentication",
            Detail = exception is AuthProblem problem ? problem.Message :
                status == 503 ? "Authentication storage is unavailable. Please try again later." : "Something went wrong. Please try again."
        }, ct);
        return true;
    }
}
