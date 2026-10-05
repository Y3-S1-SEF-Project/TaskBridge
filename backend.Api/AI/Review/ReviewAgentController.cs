using Microsoft.AspNetCore.Mvc;
using TaskBridge.Api.Notifications;

namespace backend.Api.AI;

[ApiController]
[Route("api/agent/review")]
public class ReviewAgentController : ControllerBase
{
    private readonly ReviewAgentService _reviewService;
    private readonly INotificationService _notificationService;

    public ReviewAgentController(
        ReviewAgentService reviewService,
        INotificationService notificationService)
    {
        _reviewService = reviewService;
        _notificationService = notificationService;
    }

    [HttpPost("start")]
    public async Task<IActionResult> StartJob([FromBody] StartJobRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.StartJobAsync(request, ct);
        return Ok(res);
    }

    [HttpPost("evaluate")]
    public async Task<IActionResult> EvaluateCompletion([FromBody] SubmitCompletionRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.EvaluateCompletionAsync(request, ct);
        return Ok(res);
    }

    [HttpPost("submit")]
    public async Task<IActionResult> SubmitToCustomer([FromBody] SubmitToCustomerRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var success = await _reviewService.SubmitToCustomerAsync(request, ct);
        if (success)
        {
            try
            {
                var comp = await _reviewService.GetCompletionDetailsAsync(request.BookingReference, ct);
                if (comp != null)
                {
                    await _notificationService.NotifyJobCompletedAsync(
                        comp.CustomerId,
                        comp.CustomerName,
                        comp.ProviderName,
                        comp.ServiceTitle,
                        comp.BookingReference,
                        comp.CalculatedPrice,
                        ct);
                }
            }
            catch { }
        }

        return Ok(new { success, bookingReference = request.BookingReference, status = "PendingCustomerSignOff" });
    }

    [HttpGet("{bookingRef}")]
    public async Task<IActionResult> GetCompletionDetails(string bookingRef, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(bookingRef))
            return BadRequest(new { error = "Booking reference is required." });

        var completion = await _reviewService.GetCompletionDetailsAsync(bookingRef, ct);
        if (completion == null)
            return NotFound(new { error = "No completion record found for this booking reference." });

        return Ok(completion);
    }

    [HttpPost("customer-approve")]
    public async Task<IActionResult> CustomerApprove([FromBody] CustomerApprovalRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.CustomerApproveAsync(request, ct);

        try
        {
            var comp = await _reviewService.GetCompletionDetailsAsync(request.BookingReference, ct);
            if (comp != null)
            {
                await _notificationService.SendNotificationAsync(new CreateNotificationDto
                {
                    UserId = comp.ProviderId,
                    UserName = comp.ProviderName,
                    TargetRole = "provider",
                    Title = "Job Approved & Completed!",
                    Message = $"{comp.CustomerName} approved completion of #{comp.BookingReference} ({comp.ServiceTitle}).",
                    Type = "PaymentReceived",
                    ReferenceId = comp.BookingReference,
                    ReferenceType = "Booking",
                    Metadata = new { comp.BookingReference, comp.CustomerName, comp.CalculatedPrice }
                }, ct);
            }
        }
        catch { }

        return Ok(res);
    }

    [HttpPost("request-revision")]
    public async Task<IActionResult> RequestRevision([FromBody] RequestRevisionRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.RequestRevisionAsync(request, ct);

        try
        {
            var comp = await _reviewService.GetCompletionDetailsAsync(request.BookingReference, ct);
            if (comp != null)
            {
                await _notificationService.SendNotificationAsync(new CreateNotificationDto
                {
                    UserId = comp.ProviderId,
                    UserName = comp.ProviderName,
                    TargetRole = "provider",
                    Title = "Revision Requested",
                    Message = $"{comp.CustomerName} requested a revision on #{comp.BookingReference}: {request.Reason}",
                    Type = "JobRevision",
                    ReferenceId = comp.BookingReference,
                    ReferenceType = "Booking",
                    Metadata = new { comp.BookingReference, comp.CustomerName, request.Reason }
                }, ct);
            }
        }
        catch { }

        return Ok(res);
    }

    [HttpPost("feedback")]
    public async Task<IActionResult> SubmitFeedback([FromBody] SubmitFeedbackRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.SubmitFeedbackAsync(request, ct);
        return Ok(res);
    }

    [HttpGet("feedbacks/{providerId}")]
    public async Task<IActionResult> GetProviderFeedbacks(string providerId, CancellationToken ct)
    {
        var list = await _reviewService.GetFeedbacksForProviderAsync(providerId, ct);
        return Ok(list);
    }

    [HttpGet("feedback/booking/{bookingReference}")]
    public async Task<IActionResult> GetFeedbackForBooking(string bookingReference, CancellationToken ct)
    {
        var feedback = await _reviewService.GetFeedbackForBookingAsync(bookingReference, ct);
        if (feedback == null) return NotFound(new { message = "No feedback found for this booking." });
        return Ok(feedback);
    }

    [HttpDelete("feedback/booking/{bookingReference}")]
    public async Task<IActionResult> DeleteFeedbackForBooking(string bookingReference, CancellationToken ct)
    {
        var deleted = await _reviewService.DeleteFeedbackForBookingAsync(bookingReference, ct);
        if (!deleted) return NotFound(new { message = "No feedback found for this booking." });
        return Ok(new { success = true, message = "Feedback deleted successfully." });
    }
}
