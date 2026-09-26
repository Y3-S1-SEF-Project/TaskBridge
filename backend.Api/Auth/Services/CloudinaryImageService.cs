using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TaskBridge.Api.Auth;

public interface ICloudinaryImageService
{
    Task<string> UploadProfilePhotoAsync(IFormFile file, Guid userId, CancellationToken ct);
}

public sealed class CloudinaryImageService : ICloudinaryImageService
{
    private readonly Cloudinary _cloudinary;
    private readonly ILogger<CloudinaryImageService> _logger;

    public CloudinaryImageService(IConfiguration config, ILogger<CloudinaryImageService> logger)
    {
        _logger = logger;
        var cloudName = config["Cloudinary:CloudName"] ?? "ipuwgoyi";
        var apiKey = config["Cloudinary:ApiKey"] ?? "692321869421874";
        var apiSecret = config["Cloudinary:ApiSecret"] ?? "I5hw45vpkhz6skiSnE5Z2nPgNeU";

        var account = new Account(cloudName, apiKey, apiSecret);
        _cloudinary = new Cloudinary(account);
        _cloudinary.Api.Secure = true;
    }

    public async Task<string> UploadProfilePhotoAsync(IFormFile file, Guid userId, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new AuthProblem(400, "Please select an image to upload.");

        if (file.Length > 10 * 1024 * 1024)
            throw new AuthProblem(400, "Image size exceeds maximum allowed limit (10MB).");

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".heic" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(ext))
            throw new AuthProblem(400, "Unsupported image format. Allowed: JPG, PNG, WebP, HEIC.");

        await using var stream = file.OpenReadStream();
        var publicId = $"user_{userId}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(file.FileName, stream),
            Folder = "taskbridge/profiles",
            PublicId = publicId,
            Transformation = new Transformation()
                .Width(500)
                .Height(500)
                .Crop("thumb")
                .Gravity("face"),
            Overwrite = true,
        };

        _logger.LogInformation("Uploading profile photo for user {UserId} to Cloudinary...", userId);
        var uploadResult = await _cloudinary.UploadAsync(uploadParams, ct);

        if (uploadResult.Error is not null)
        {
            _logger.LogError("Cloudinary error: {Error}", uploadResult.Error.Message);
            throw new AuthProblem(500, $"Failed to upload photo to Cloudinary: {uploadResult.Error.Message}");
        }

        _logger.LogInformation("Successfully uploaded to Cloudinary: {Url}", uploadResult.SecureUrl);
        return uploadResult.SecureUrl.ToString();
    }
}
