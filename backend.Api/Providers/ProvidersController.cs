using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;
using TaskBridge.Api.Common;

namespace TaskBridge.Api.Providers;

[ApiController]
[Route("api/providers")]
public class ProvidersController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly ILogger<ProvidersController> _logger;

    public ProvidersController(AuthDbContext db, ILogger<ProvidersController> logger)
    {
        _db = db;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetProviders(
        [FromQuery] string? query,
        [FromQuery] string? category,
        [FromQuery] string? location,
        [FromQuery] double? lat,
        [FromQuery] double? lng,
        [FromQuery] string? sortBy,
        [FromQuery] string? excludeUserId,
        [FromQuery] string? excludeName,
        [FromQuery] int limit = 20,
        CancellationToken ct = default)
    {
        try
        {
            var q = _db.Providers
                .Include(p => p.User)
                .Where(p => p.IsActive)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(excludeUserId) && Guid.TryParse(excludeUserId, out var exGuid))
            {
                q = q.Where(p => p.UserId != exGuid);
            }

            if (!string.IsNullOrWhiteSpace(excludeName))
            {
                var exName = excludeName.Trim().ToLower();
                q = q.Where(p => p.User == null || p.User.FullName.ToLower() != exName);
            }

            if (!string.IsNullOrWhiteSpace(category) && !category.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                var catTerm = category.Trim().ToLower();
                q = q.Where(p => p.Category.ToLower().Contains(catTerm) || 
                                 (p.Skills != null && p.Skills.ToLower().Contains(catTerm)) ||
                                 (p.User.ProviderCategory != null && p.User.ProviderCategory.ToLower().Contains(catTerm)));
            }

            if (!string.IsNullOrWhiteSpace(query))
            {
                var term = query.Trim().ToLower();
                q = q.Where(p => p.Category.ToLower().Contains(term) ||
                                 p.User.FullName.ToLower().Contains(term) ||
                                 (p.Skills != null && p.Skills.ToLower().Contains(term)) ||
                                 (p.Services != null && p.Services.ToLower().Contains(term)) ||
                                 (p.Bio != null && p.Bio.ToLower().Contains(term)) ||
                                 (p.ServiceAreas != null && p.ServiceAreas.ToLower().Contains(term)));
            }

            var providers = await q.Take(limit).ToListAsync(ct);

            // Determine customer's exact geographical coordinates
            (double cLat, double cLng) customerCoords = (6.8415, 79.9056); // default Boralesgamuwa
            if (lat.HasValue && lng.HasValue && lat.Value != 0 && lng.Value != 0)
            {
                customerCoords = (lat.Value, lng.Value);
            }
            else if (!string.IsNullOrWhiteSpace(location))
            {
                customerCoords = ResolveCoordinates(location);
            }

            var pIds = providers.Select(p => p.Id).ToList();
            var uIds = providers.Select(p => p.UserId).ToList();
            var feedbacks = await _db.Feedbacks.AsNoTracking()
                .Where(f => (f.ProviderId.HasValue && (pIds.Contains(f.ProviderId.Value) || uIds.Contains(f.ProviderId.Value))))
                .ToListAsync(ct);

            var resultList = providers.Select(p =>
            {
                var user = p.User;
                var displayCategory = !string.IsNullOrWhiteSpace(p.Category) && !p.Category.Equals("General", StringComparison.OrdinalIgnoreCase)
                    ? p.Category
                    : (!string.IsNullOrWhiteSpace(user.ProviderCategory) ? user.ProviderCategory : "Specialist");

                // Resolve provider's actual coordinates from location/service area/address
                var providerLocationStr = p.ServiceAreas ?? user.ProviderServiceAreas ?? user.Location ?? user.Address ?? "Colombo";
                var (pLat, pLng) = ResolveCoordinates(providerLocationStr);

                // Calculate real mathematical geodesic distance using Haversine formula
                var realDistance = CalculateHaversineDistance(customerCoords.cLat, customerCoords.cLng, pLat, pLng);

                // Derive exact live reviews from database feedbacks
                var pFeedbacks = feedbacks.Where(f => f.ProviderId == p.Id || f.ProviderId == p.UserId).ToList();
                var realCount = pFeedbacks.Count;
                var realRating = realCount > 0 ? Math.Round(pFeedbacks.Average(f => f.Rating), 1) : 0.0;

                return new ProviderDto
                {
                    Id = p.Id,
                    UserId = p.UserId,
                    FullName = !string.IsNullOrWhiteSpace(user.FullName) ? user.FullName : "TaskBridge Specialist",
                    ProfilePhotoUrl = user.ProfilePhotoUrl,
                    Phone = user.Phone,
                    Category = displayCategory,
                    Skills = p.Skills ?? user.ProviderSkills,
                    Services = p.Services ?? user.ProviderServices,
                    Experience = p.Experience ?? user.ProviderExperience,
                    Certifications = p.Certifications ?? user.ProviderCertifications,
                    ServiceAreas = p.ServiceAreas ?? user.ProviderServiceAreas ?? user.Location ?? "Colombo",
                    HourlyRate = p.HourlyRate > 0 ? p.HourlyRate : (user.ProviderHourlyRate ?? 2500m),
                    Rating = realRating,
                    ReviewCount = realCount,
                    DistanceKm = realDistance,
                    Latitude = pLat,
                    Longitude = pLng,
                    Bio = p.Bio ?? user.ProviderBio ?? "Experienced professional delivering quality services.",
                    IsActive = p.IsActive
                };
            }).ToList();

            // Apply requested sort order
            var sort = (sortBy ?? "distance").Trim().ToLowerInvariant();
            IEnumerable<ProviderDto> sorted = sort switch
            {
                "rating" => resultList.OrderByDescending(p => p.Rating).ThenByDescending(p => p.ReviewCount),
                "price_asc" => resultList.OrderBy(p => p.HourlyRate).ThenBy(p => p.DistanceKm),
                "price_desc" => resultList.OrderByDescending(p => p.HourlyRate).ThenBy(p => p.DistanceKm),
                "reviews" => resultList.OrderByDescending(p => p.ReviewCount).ThenByDescending(p => p.Rating),
                _ => resultList.OrderBy(p => p.DistanceKm).ThenByDescending(p => p.Rating)
            };

            return Ok(sorted.ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get providers");
            return StatusCode(500, new { message = "Error fetching providers" });
        }
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetProviderById(Guid id, CancellationToken ct = default)
    {
        var p = await _db.Providers
            .Include(p => p.User)
            .FirstOrDefaultAsync(x => x.Id == id, ct);

        if (p == null) return NotFound(new { message = "Provider not found" });

        var user = p.User;
        var displayCategory = !string.IsNullOrWhiteSpace(p.Category) && !p.Category.Equals("General", StringComparison.OrdinalIgnoreCase)
            ? p.Category
            : (!string.IsNullOrWhiteSpace(user.ProviderCategory) ? user.ProviderCategory : "Specialist");

        var providerLocationStr = p.ServiceAreas ?? user.ProviderServiceAreas ?? user.Location ?? "Colombo";
        var (pLat, pLng) = ResolveCoordinates(providerLocationStr);

        var pFeedbacks = await _db.Feedbacks.AsNoTracking()
            .Where(f => f.ProviderId == p.Id || f.ProviderId == p.UserId)
            .ToListAsync(ct);
        var realCount = pFeedbacks.Count;
        var realRating = realCount > 0 ? Math.Round(pFeedbacks.Average(f => f.Rating), 1) : 0.0;

        return Ok(new ProviderDto
        {
            Id = p.Id,
            UserId = p.UserId,
            FullName = !string.IsNullOrWhiteSpace(user.FullName) ? user.FullName : "TaskBridge Specialist",
            ProfilePhotoUrl = user.ProfilePhotoUrl,
            Phone = user.Phone,
            Category = displayCategory,
            Skills = p.Skills ?? user.ProviderSkills,
            Services = p.Services ?? user.ProviderServices,
            Experience = p.Experience ?? user.ProviderExperience,
            Certifications = p.Certifications ?? user.ProviderCertifications,
            ServiceAreas = p.ServiceAreas ?? user.ProviderServiceAreas ?? user.Location ?? "Colombo",
            HourlyRate = p.HourlyRate > 0 ? p.HourlyRate : (user.ProviderHourlyRate ?? 2500m),
            Rating = realRating,
            ReviewCount = realCount,
            DistanceKm = 2.4,
            Latitude = pLat,
            Longitude = pLng,
            Bio = p.Bio ?? user.ProviderBio ?? "Experienced professional delivering quality services.",
            IsActive = p.IsActive
        });
    }

    private static (double Lat, double Lng) ResolveCoordinates(string locationText)
        => GeoUtils.ResolveCoordinates(locationText);

    private static double CalculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)
        => GeoUtils.CalculateHaversineDistance(lat1, lon1, lat2, lon2);
}

public class ProviderDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? ProfilePhotoUrl { get; set; }
    public string Phone { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string? Skills { get; set; }
    public string? Services { get; set; }
    public string? Experience { get; set; }
    public string? Certifications { get; set; }
    public string? ServiceAreas { get; set; }
    public decimal HourlyRate { get; set; }
    public double Rating { get; set; }
    public int ReviewCount { get; set; }
    public double DistanceKm { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? Bio { get; set; }
    public bool IsActive { get; set; }
}
