using Microsoft.AspNetCore.Mvc;

namespace backend.Api.AI;

[ApiController]
[Route("api/agent/coordination")]
public class CoordinationAgentController : ControllerBase
{
    private readonly CoordinationAgentService _coordinationService;
    private readonly ILogger<CoordinationAgentController> _logger;

    public CoordinationAgentController(
        CoordinationAgentService coordinationService,
        ILogger<CoordinationAgentController> logger)
    {
        _coordinationService = coordinationService;
        _logger = logger;
    }

    /// <summary>
    /// Evaluates provider quotations against customer constraints, picks the best proposal,
    /// and generates Explainable AI rationale (XAI).
    /// </summary>
    [HttpPost("evaluate")]
    public async Task<IActionResult> EvaluateQuotations(
        [FromBody] CoordinationEvaluateRequest request,
        CancellationToken ct)
    {
        try
        {
            var result = await _coordinationService.EvaluateQuotationsAsync(request, ct);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred during quotation evaluation in Agent 3");
            return StatusCode(500, new { message = "An error occurred while evaluating quotations." });
        }
    }

    /// <summary>
    /// Confirms the booking upon customer acceptance (Human-in-the-Loop).
    /// </summary>
    [HttpPost("confirm")]
    public async Task<IActionResult> ConfirmBooking(
        [FromBody] ConfirmBookingRequest request,
        CancellationToken ct)
    {
        try
        {
            var booking = await _coordinationService.ConfirmBookingAsync(request, ct);
            return Ok(new
            {
                success = true,
                message = $"Booking confirmed successfully with reference {booking.BookingReference}",
                booking
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while confirming booking");
            return StatusCode(500, new { message = "An error occurred while confirming booking." });
        }
    }

    /// <summary>
    /// Retrieves live bookings for customer/provider dashboard.
    /// </summary>
    [HttpGet("bookings")]
    public async Task<IActionResult> GetBookings(
        [FromQuery] string? providerId,
        [FromQuery] string? status,
        CancellationToken ct)
    {
        try
        {
            var list = await _coordinationService.GetBookingsAsync(providerId, status, ct);
            return Ok(list);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching bookings");
            return StatusCode(500, new { message = "An error occurred while retrieving bookings." });
        }
    }

    /// <summary>
    /// Updates the status of a job booking (e.g. Upcoming -> Active -> Completed).
    /// </summary>
    [HttpPost("update-status")]
    public async Task<IActionResult> UpdateBookingStatus(
        [FromBody] UpdateBookingStatusRequest request,
        CancellationToken ct)
    {
        try
        {
            var updated = await _coordinationService.UpdateBookingStatusAsync(request, ct);
            if (updated == null)
            {
                return NotFound(new { message = "Booking not found." });
            }
            return Ok(new { success = true, booking = updated });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating booking status");
            return StatusCode(500, new { message = "An error occurred while updating status." });
        }
    }
}
