using Microsoft.AspNetCore.Mvc;
using TaskBridge.Api.Auth;

namespace backend.Api.AI;

[ApiController]
[Route("api/proofs")]
public class ProofUploadController : ControllerBase
{
    private readonly IProfileImageService _imageService;
    private readonly ILogger<ProofUploadController> _logger;

    public ProofUploadController(IProfileImageService imageService, ILogger<ProofUploadController> logger)
    {
        _imageService = imageService;
        _logger = logger;
    }

    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadProof(
        IFormFile file,
        [FromForm] string? bookingRef,
        CancellationToken ct)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { error = "No file was uploaded." });
        }

        try
        {
            var url = await _imageService.UploadProofPhotoAsync(file, bookingRef ?? "job", ct);
            return Ok(new { url });
        }
        catch (AuthProblem ex)
        {
            return StatusCode(ex.Status, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error uploading proof image.");
            return StatusCode(500, new { error = "An error occurred while uploading the proof photo." });
        }
    }
}
