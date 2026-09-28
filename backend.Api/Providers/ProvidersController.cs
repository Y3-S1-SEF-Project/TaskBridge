using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskBridge.Api.Data;

namespace TaskBridge.Api.Providers;

[ApiController]
[Route("api/providers")]
public class ProvidersController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly ILogger<ProvidersController> _logger;

    // Comprehensive Sri Lanka geographic coordinates table (Latitude, Longitude)
    private static readonly Dictionary<string, (double Lat, double Lng)> SriLankaLocations = new(StringComparer.OrdinalIgnoreCase)
    {
        { "Boralesgamuwa", (6.8415, 79.9056) },
        { "Maharagama", (6.8480, 79.9265) },
        { "Nugegoda", (6.8649, 79.8997) },
        { "Dehiwala", (6.8517, 79.8653) },
        { "Mount Lavinia", (6.8333, 79.8667) },
        { "Colombo 05", (6.8833, 79.8653) },
        { "Colombo 03", (6.9065, 79.8524) },
        { "Colombo 07", (6.9117, 79.8646) },
        { "Colombo 04", (6.8920, 79.8576) },
        { "Colombo 06", (6.8741, 79.8605) },
        { "Colombo 02", (6.9205, 79.8540) },
        { "Colombo 01", (6.9360, 79.8450) },
        { "Colombo", (6.9271, 79.8612) },
        { "Pannipitiya", (6.8436, 79.9547) },
        { "Kottawa", (6.8414, 79.9654) },
        { "Homagama", (6.8433, 80.0031) },
        { "Battaramulla", (6.8986, 79.9186) },
        { "Rajagiriya", (6.9089, 79.8928) },
        { "Malabe", (6.9042, 79.9547) },
        { "Kaduwela", (6.9333, 79.9833) },
        { "Moratuwa", (6.7730, 79.8816) },
        { "Piliyandala", (6.8018, 79.9227) },
        { "Ratmalana", (6.8188, 79.8828) },
        { "Angoda", (6.9286, 79.9186) },
        { "Kelaniya", (6.9536, 79.9217) },
        { "Wattala", (6.9906, 79.8911) },
        { "Kiribathgoda", (6.9794, 79.9278) },
        { "Kadawatha", (7.0017, 79.9525) },
        { "Negombo", (7.2008, 79.8737) },
        { "Gampaha", (7.0840, 79.9943) },
        { "Panadura", (6.7133, 79.9078) },
        { "Kalutara", (6.5854, 79.9607) },
        { "Kandy", (7.2906, 80.6337) },
        { "Galle", (6.0535, 80.2210) },
        { "Kurunegala", (7.4863, 80.3623) }
    };


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
                    Rating = p.Rating > 0 ? p.Rating : 4.8,
                    ReviewCount = p.ReviewCount > 0 ? p.ReviewCount : 18,
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
            Rating = p.Rating > 0 ? p.Rating : 4.8,
            ReviewCount = p.ReviewCount > 0 ? p.ReviewCount : 18,
            DistanceKm = 2.4,
            Latitude = pLat,
            Longitude = pLng,
            Bio = p.Bio ?? user.ProviderBio ?? "Experienced professional delivering quality services.",
            IsActive = p.IsActive
        });
    }

    private static (double Lat, double Lng) ResolveCoordinates(string locationText)
    {
        if (string.IsNullOrWhiteSpace(locationText))
            return (6.9271, 79.8612); // Colombo default

        foreach (var kvp in SriLankaLocations)
        {
            if (locationText.Contains(kvp.Key, StringComparison.OrdinalIgnoreCase))
                return kvp.Value;
        }

        return (6.9271, 79.8612);
    }

    private static double CalculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6371.0; // Earth's radius in kilometers
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var rLat1 = lat1 * Math.PI / 180.0;
        var rLat2 = lat2 * Math.PI / 180.0;

        var a = Math.Sin(dLat / 2.0) * Math.Sin(dLat / 2.0) +
                Math.Sin(dLon / 2.0) * Math.Sin(dLon / 2.0) * Math.Cos(rLat1) * Math.Cos(rLat2);
        var c = 2.0 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1.0 - a));

        var dist = R * c;
        return dist < 0.5 ? 0.5 : Math.Round(dist, 1);
    }
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
