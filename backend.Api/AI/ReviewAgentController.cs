using Microsoft.AspNetCore.Mvc;

namespace backend.Api.AI;

[ApiController]
[Route("api/agent/review")]
public class ReviewAgentController : ControllerBase
{
    private readonly ReviewAgentService _reviewService;

    public ReviewAgentController(ReviewAgentService reviewService)
    {
        _reviewService = reviewService;
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
        return Ok(res);
    }

    [HttpPost("request-revision")]
    public async Task<IActionResult> RequestRevision([FromBody] RequestRevisionRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.BookingReference))
            return BadRequest(new { error = "Booking reference is required." });

        var res = await _reviewService.RequestRevisionAsync(request, ct);
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
    public async Task<IActionResult> GetProviderFeedbacks(Guid providerId, CancellationToken ct)
    {
        var list = await _reviewService.GetFeedbacksForProviderAsync(providerId, ct);
        return Ok(list);
    }
}
