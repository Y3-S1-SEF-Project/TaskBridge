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
        [FromQuery] string? providerName,
        [FromQuery] string? customerName,
        [FromQuery] string? status,
        CancellationToken ct)
    {
        try
        {
            var list = await _coordinationService.GetBookingsAsync(providerId, providerName, customerName, status, ct);
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

    /// <summary>
    /// Persists an open quotation proposal (status = "Pending") into the 'proposals' table.
    /// </summary>
    [HttpPost("request-quote")]
    public async Task<IActionResult> CreateQuotationRequest(
        [FromBody] CreateQuotationRequest request,
        CancellationToken ct)
    {
        try
        {
            var proposal = await _coordinationService.CreateProposalAsync(request, ct);
            return Ok(new
            {
                success = true,
                message = $"Proposal created with reference {proposal.ProposalReference}",
                proposal = proposal,
                booking = new
                {
                    proposal.Id,
                    BookingReference = proposal.ProposalReference,
                    proposal.CustomerName,
                    proposal.ProviderName,
                    proposal.ServiceTitle,
                    proposal.Category,
                    proposal.Location,
                    Schedule = proposal.PreferredSchedule,
                    Price = proposal.EstimatedRate,
                    proposal.Status,
                    proposal.CreatedAt
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating quotation proposal");
            return StatusCode(500, new { message = "An error occurred while creating proposal." });
        }
    }

    /// <summary>
    /// Retrieves live proposals from the 'proposals' table.
    /// </summary>
    [HttpGet("proposals")]
    public async Task<IActionResult> GetProposals(
        [FromQuery] string? providerId,
        [FromQuery] string? providerName,
        [FromQuery] string? customerName,
        [FromQuery] string? status,
        CancellationToken ct)
    {
        try
        {
            var list = await _coordinationService.GetProposalsAsync(providerId, providerName, customerName, status, ct);
            return Ok(list);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching proposals");
            return StatusCode(500, new { message = "An error occurred while retrieving proposals." });
        }
    }

    /// <summary>
    /// Provider accepts a proposal, marking it as Accepted and creating an Upcoming booking in 'bookings' table.
    /// </summary>
    [HttpPost("proposals/accept")]
    public async Task<IActionResult> AcceptProposal(
        [FromBody] AcceptProposalRequest request,
        CancellationToken ct)
    {
        try
        {
            var booking = await _coordinationService.AcceptProposalAsync(request, ct);
            if (booking == null)
            {
                return NotFound(new { message = "Proposal not found." });
            }
            return Ok(new { success = true, booking });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error accepting proposal");
            return StatusCode(500, new { message = "An error occurred while accepting proposal." });
        }
    }

    /// <summary>
    /// Provider declines a proposal, marking it as Declined.
    /// </summary>
    [HttpPost("proposals/decline")]
    public async Task<IActionResult> DeclineProposal(
        [FromBody] DeclineProposalRequest request,
        CancellationToken ct)
    {
        try
        {
            var proposal = await _coordinationService.DeclineProposalAsync(request, ct);
            if (proposal == null)
            {
                return NotFound(new { message = "Proposal not found." });
            }
            return Ok(new { success = true, proposal });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error declining proposal");
            return StatusCode(500, new { message = "An error occurred while declining proposal." });
        }
    }

    /// <summary>
    /// Submits a provider counter-bid or updated quote.
    /// </summary>
    [HttpPost("counter-bid")]
    public async Task<IActionResult> SubmitCounterBid(
        [FromBody] ProviderCounterBidRequest request,
        CancellationToken ct)
    {
        try
        {
            var updated = await _coordinationService.SubmitCounterBidAsync(request, ct);
            if (updated == null)
            {
                return NotFound(new { message = "Booking request not found." });
            }
            return Ok(new { success = true, booking = updated });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error submitting counter-bid");
            return StatusCode(500, new { message = "An error occurred while submitting counter-bid." });
        }
    }

    /// <summary>
    /// Cancels a booking or quotation request.
    /// </summary>
    [HttpPost("cancel")]
    public async Task<IActionResult> CancelBooking(
        [FromBody] CancelBookingRequest request,
        CancellationToken ct)
    {
        try
        {
            var updated = await _coordinationService.CancelBookingAsync(request, ct);
            if (updated == null)
            {
                return NotFound(new { message = "Booking request not found." });
            }
            return Ok(new { success = true, booking = updated });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling booking");
            return StatusCode(500, new { message = "An error occurred while cancelling booking." });
        }
    }
}


