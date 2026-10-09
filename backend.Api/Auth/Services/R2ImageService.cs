using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TaskBridge.Api.Auth;

public interface IProfileImageService
{
    Task<string> UploadProfilePhotoAsync(IFormFile file, Guid userId, CancellationToken ct);
    Task<string> UploadProofPhotoAsync(IFormFile file, string bookingRef, CancellationToken ct);
    Task<string> UploadVerificationDocumentAsync(IFormFile file, Guid userId, string docType, CancellationToken ct);
}

public sealed class R2ImageService : IProfileImageService
{
    private readonly IAmazonS3 _s3Client;
    private readonly string _bucketName;
    private readonly string _publicUrl;
    private readonly ILogger<R2ImageService> _logger;

    public R2ImageService(IConfiguration config, ILogger<R2ImageService> logger)
    {
        _logger = logger;
        var accountId = config["CloudflareR2:AccountId"] ?? "de81d9bb7303e6b962b82b4819acd898";
        var accessKey = config["CloudflareR2:AccessKeyId"] ?? "91afc5cce188e407a0bc567f3cf30700";
        var secretKey = config["CloudflareR2:SecretAccessKey"] ?? "be9573c851b601f1f8695019e17e7db947dfe550bce72ee7be54fc66147fa94a";
        _bucketName = config["CloudflareR2:BucketName"] ?? "taskbridge-media";
        _publicUrl = (config["CloudflareR2:PublicUrl"] ?? "https://pub-9b98c8a23fb64541881a8a8d9f92d7e5.r2.dev").TrimEnd('/');

        var credentials = new BasicAWSCredentials(accessKey, secretKey);
        var s3Config = new AmazonS3Config
        {
            ServiceURL = $"https://{accountId}.r2.cloudflarestorage.com",
            ForcePathStyle = true
        };

        _s3Client = new AmazonS3Client(credentials, s3Config);
    }

    public async Task<string> UploadProfilePhotoAsync(IFormFile file, Guid userId, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new AuthProblem(400, "Please select an image to upload.");

        if (file.Length > 10 * 1024 * 1024)
            throw new AuthProblem(400, "Image size exceeds maximum allowed limit (10MB).");

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf", ".doc", ".docx" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || !allowedExtensions.Contains(ext))
            ext = ".jpg";

        var folder = (ext == ".pdf" || ext == ".doc" || ext == ".docx") ? "certifications" : "profiles";
        var key = $"{folder}/user_{userId}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}{ext}";

        await using var stream = file.OpenReadStream();
        var contentType = ext switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".heic" => "image/heic",
            ".pdf" => "application/pdf",
            ".doc" => "application/msword",
            ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            _ => "image/jpeg"
        };

        var putRequest = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = key,
            InputStream = stream,
            ContentType = contentType,
            Headers =
            {
                CacheControl = "public, max-age=31536000, immutable"
            },
            DisablePayloadSigning = true
        };

        _logger.LogInformation("Uploading profile photo to Cloudflare R2 bucket {Bucket}: {Key}...", _bucketName, key);
        var response = await _s3Client.PutObjectAsync(putRequest, ct);

        if (response.HttpStatusCode != System.Net.HttpStatusCode.OK)
        {
            _logger.LogError("R2 upload failed with status {Status}", response.HttpStatusCode);
            throw new AuthProblem(500, "Failed to upload photo to Cloudflare R2 storage.");
        }

        var publicImageUrl = $"{_publicUrl}/{key}";
        _logger.LogInformation("Successfully uploaded to Cloudflare R2: {Url}", publicImageUrl);
        return publicImageUrl;
    }

    public async Task<string> UploadProofPhotoAsync(IFormFile file, string bookingRef, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new AuthProblem(400, "Please select a proof photo to upload.");

        if (file.Length > 15 * 1024 * 1024)
            throw new AuthProblem(400, "Proof image size exceeds maximum allowed limit (15MB).");

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".heic" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || !allowedExtensions.Contains(ext))
            ext = ".jpg";

        var safeRef = string.IsNullOrWhiteSpace(bookingRef) ? "general" : bookingRef.Replace("#", "").Trim();
        var key = $"proofs/{safeRef}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}_{Guid.NewGuid().ToString("N")[..6]}{ext}";

        await using var stream = file.OpenReadStream();
        var contentType = ext switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".heic" => "image/heic",
            _ => "image/jpeg"
        };

        var putRequest = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = key,
            InputStream = stream,
            ContentType = contentType,
            Headers =
            {
                CacheControl = "public, max-age=31536000, immutable"
            },
            DisablePayloadSigning = true
        };

        _logger.LogInformation("Uploading completion proof to Cloudflare R2: {Key}...", key);
        var response = await _s3Client.PutObjectAsync(putRequest, ct);

        if (response.HttpStatusCode != System.Net.HttpStatusCode.OK)
        {
            _logger.LogError("R2 proof upload failed with status {Status}", response.HttpStatusCode);
            throw new AuthProblem(500, "Failed to upload proof photo to Cloudflare R2 storage.");
        }

        var publicImageUrl = $"{_publicUrl}/{key}";
        _logger.LogInformation("Successfully uploaded proof to Cloudflare R2: {Url}", publicImageUrl);
        return publicImageUrl;
    }

    public async Task<string> UploadVerificationDocumentAsync(IFormFile file, Guid userId, string docType, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new AuthProblem(400, "Please select an ID or Driving License photo to upload.");

        if (file.Length > 15 * 1024 * 1024)
            throw new AuthProblem(400, "Verification document image exceeds maximum allowed limit (15MB).");

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || !allowedExtensions.Contains(ext))
            ext = ".jpg";

        var safeType = (docType ?? "id").ToLowerInvariant().Contains("driv") ? "dl" : "nic";
        var key = $"verifications/user_{userId}_{safeType}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}{ext}";

        await using var stream = file.OpenReadStream();
        var contentType = ext switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".heic" => "image/heic",
            ".pdf" => "application/pdf",
            _ => "image/jpeg"
        };

        var putRequest = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = key,
            InputStream = stream,
            ContentType = contentType,
            Headers =
            {
                CacheControl = "public, max-age=31536000, immutable"
            },
            DisablePayloadSigning = true
        };

        _logger.LogInformation("Uploading provider verification document ({Type}) to Cloudflare R2: {Key}...", docType, key);
        var response = await _s3Client.PutObjectAsync(putRequest, ct);

        if (response.HttpStatusCode != System.Net.HttpStatusCode.OK)
        {
            _logger.LogError("R2 verification document upload failed with status {Status}", response.HttpStatusCode);
            throw new AuthProblem(500, "Failed to upload verification document to Cloudflare R2 storage.");
        }

        var publicImageUrl = $"{_publicUrl}/{key}";
        _logger.LogInformation("Successfully uploaded verification document to Cloudflare R2: {Url}", publicImageUrl);
        return publicImageUrl;
    }
}
