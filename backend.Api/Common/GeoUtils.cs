namespace TaskBridge.Api.Common;

public static class GeoUtils
{
    // Comprehensive Sri Lanka geographic coordinates table (Latitude, Longitude)
    public static readonly Dictionary<string, (double Lat, double Lng)> SriLankaLocations = new(StringComparer.OrdinalIgnoreCase)
    {
        { "Boralesgamuwa", (6.8415, 79.9056) },
        { "Maharagama", (6.8480, 79.9265) },
        { "Nugegoda", (6.8649, 79.8997) },
        { "High Level Road", (6.8600, 79.9050) },
        { "High Level", (6.8600, 79.9050) },
        { "Dehiwala", (6.8517, 79.8653) },
        { "Mount Lavinia", (6.8333, 79.8667) },
        { "Colombo 05", (6.8833, 79.8653) },
        { "Havelock", (6.8833, 79.8653) },
        { "Colombo 03", (6.9065, 79.8524) },
        { "Kollupitiya", (6.9065, 79.8524) },
        { "Colombo 07", (6.9117, 79.8646) },
        { "Cinnamon Gardens", (6.9117, 79.8646) },
        { "Colombo 04", (6.8920, 79.8576) },
        { "Bambalapitiya", (6.8920, 79.8576) },
        { "Colombo 06", (6.8741, 79.8605) },
        { "Wellawatte", (6.8741, 79.8605) },
        { "Colombo 02", (6.9205, 79.8540) },
        { "Slave Island", (6.9205, 79.8540) },
        { "Colombo 01", (6.9360, 79.8450) },
        { "Fort", (6.9360, 79.8450) },
        { "Colombo 08", (6.9147, 79.8778) },
        { "Borella", (6.9147, 79.8778) },
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
        { "Peradeniya", (7.2583, 80.5967) },
        { "Galle", (6.0535, 80.2210) },
        { "Matara", (5.9549, 80.5550) },
        { "Kurunegala", (7.4863, 80.3623) }
    };

    public static (double Lat, double Lng) ResolveCoordinates(string? locationText)
    {
        if (string.IsNullOrWhiteSpace(locationText))
            return (6.8415, 79.9056); // default hub

        foreach (var kvp in SriLankaLocations)
        {
            if (locationText.Contains(kvp.Key, StringComparison.OrdinalIgnoreCase))
                return kvp.Value;
        }

        return (6.9271, 79.8612); // Colombo default
    }

    public static double CalculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)
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
