import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserLocation {
  final String shortName;
  final String address;
  final double latitude;
  final double longitude;

  const UserLocation({
    required this.shortName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'shortName': shortName,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    shortName: json['shortName'] as String? ?? 'Colombo',
    address: json['address'] as String? ?? 'Colombo, Sri Lanka',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 79.8612,
  );

  // Default fallback location: Colombo, Sri Lanka
  static const defaultLocation = UserLocation(
    shortName: 'Colombo 05',
    address: 'Colombo 05, Western Province, Sri Lanka',
    latitude: 6.8833,
    longitude: 79.8653,
  );
}

class LocationException implements Exception {
  final String message;
  final bool isPermanentlyDenied;
  final bool isServiceDisabled;

  const LocationException(
    this.message, {
    this.isPermanentlyDenied = false,
    this.isServiceDisabled = false,
  });

  @override
  String toString() => message;
}

class LocationService {
  static const _savedLocationKey = 'taskbridge.saved_location_name';
  static const _savedLatKey = 'taskbridge.saved_location_lat';
  static const _savedLngKey = 'taskbridge.saved_location_lng';
  static final _geocoding = Geocoding();

  // Requests permission and gets the device's live GPS coordinates.
  static Future<UserLocation?> determineCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'GPS is turned off. Please enable Location in your device settings.',
        isServiceDisabled: true,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission was denied. Please allow access to use current location.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Tap to open Settings.',
        isPermanentlyDenied: true,
      );
    }

    Position? position;

    // 1. Fast path: check last known position first (instant on both emulator and real phone)
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    // 2. If no last known position, query location with medium accuracy & short 4s timeout
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (e) {
        debugPrint('getCurrentPosition timeout or error: $e');
      }
    }

    // 3. Fallback for fresh emulators that have not emitted simulated GPS: use default coordinates
    final lat = position?.latitude ?? UserLocation.defaultLocation.latitude;
    final lng = position?.longitude ?? UserLocation.defaultLocation.longitude;

    final location = await getAddressFromCoordinates(lat, lng);
    await saveLocation(location);
    return location;
  }

  // Reverse geocodes latitude/longitude to clean readable text.
  static Future<UserLocation> getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      final placemarks = await _geocoding
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 4));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Build clean short name (e.g., "Colombo 05" or "Nugegoda")
        String short = '';
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          short = place.subLocality!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          short = place.locality!;
        } else if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty) {
          short = place.subAdministrativeArea!;
        } else {
          short = place.name ?? 'Location';
        }

        // Build descriptive full address
        final parts = <String>[];
        if (place.name != null &&
            place.name!.isNotEmpty &&
            place.name != short) {
          parts.add(place.name!);
        }
        if (place.street != null &&
            place.street!.isNotEmpty &&
            !parts.contains(place.street)) {
          parts.add(place.street!);
        }
        if (place.subLocality != null &&
            place.subLocality!.isNotEmpty &&
            !parts.contains(place.subLocality)) {
          parts.add(place.subLocality!);
        }
        if (place.locality != null &&
            place.locality!.isNotEmpty &&
            !parts.contains(place.locality)) {
          parts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          parts.add(place.country!);
        }

        final full = parts.isEmpty ? short : parts.join(', ');

        return UserLocation(
          shortName: short,
          address: full,
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (e) {
      debugPrint('Reverse geocoding native error: $e');
    }

    // Try Nominatim fallback if native geocoding timed out or failed
    final fallback = await _fallbackReverseNominatim(lat, lng);
    if (fallback != null) {
      return fallback;
    }

    return UserLocation(
      shortName: 'Selected Area',
      address: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
      latitude: lat,
      longitude: lng,
    );
  }

  /// Curated index of key Sri Lankan cities & hubs for instant 0ms autocomplete
  static const List<UserLocation> popularSriLankanPlaces = [
    UserLocation(
      shortName: 'Maharagama',
      address: 'Maharagama, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8480,
      longitude: 79.9268,
    ),
    UserLocation(
      shortName: 'Mahara',
      address: 'Mahara, Gampaha District, Western Province, Sri Lanka',
      latitude: 7.0167,
      longitude: 79.9333,
    ),
    UserLocation(
      shortName: 'Colombo 05 (Havelock Town)',
      address: 'Colombo 05, Western Province, Sri Lanka',
      latitude: 6.8833,
      longitude: 79.8653,
    ),
    UserLocation(
      shortName: 'Colombo 03 (Kollupitiya)',
      address: 'Colombo 03, Western Province, Sri Lanka',
      latitude: 6.9038,
      longitude: 79.8519,
    ),
    UserLocation(
      shortName: 'Colombo 07 (Cinnamon Gardens)',
      address: 'Colombo 07, Western Province, Sri Lanka',
      latitude: 6.9117,
      longitude: 79.8646,
    ),
    UserLocation(
      shortName: 'Colombo 04 (Bambalapitiya)',
      address: 'Colombo 04, Western Province, Sri Lanka',
      latitude: 6.8905,
      longitude: 79.8580,
    ),
    UserLocation(
      shortName: 'Colombo 01 (Fort)',
      address: 'Colombo 01, Western Province, Sri Lanka',
      latitude: 6.9344,
      longitude: 79.8428,
    ),
    UserLocation(
      shortName: 'Colombo 06 (Wellawatte)',
      address: 'Colombo 06, Western Province, Sri Lanka',
      latitude: 6.8741,
      longitude: 79.8611,
    ),
    UserLocation(
      shortName: 'Colombo 08 (Borella)',
      address: 'Colombo 08, Western Province, Sri Lanka',
      latitude: 6.9147,
      longitude: 79.8778,
    ),
    UserLocation(
      shortName: 'Nugegoda',
      address: 'Nugegoda, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8649,
      longitude: 79.8997,
    ),
    UserLocation(
      shortName: 'Dehiwala',
      address: 'Dehiwala-Mount Lavinia, Western Province, Sri Lanka',
      latitude: 6.8511,
      longitude: 79.8653,
    ),
    UserLocation(
      shortName: 'Mount Lavinia',
      address: 'Mount Lavinia, Western Province, Sri Lanka',
      latitude: 6.8344,
      longitude: 79.8658,
    ),
    UserLocation(
      shortName: 'Moratuwa',
      address: 'Moratuwa, Colombo District, Western Province, Sri Lanka',
      latitude: 6.7730,
      longitude: 79.8816,
    ),
    UserLocation(
      shortName: 'Kottawa',
      address: 'Kottawa, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8413,
      longitude: 79.9654,
    ),
    UserLocation(
      shortName: 'Pannipitiya',
      address: 'Pannipitiya, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8471,
      longitude: 79.9538,
    ),
    UserLocation(
      shortName: 'Homagama',
      address: 'Homagama, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8436,
      longitude: 80.0031,
    ),
    UserLocation(
      shortName: 'Malabe',
      address: 'Malabe, Colombo District, Western Province, Sri Lanka',
      latitude: 6.9042,
      longitude: 79.9547,
    ),
    UserLocation(
      shortName: 'Battaramulla',
      address: 'Battaramulla, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8997,
      longitude: 79.9171,
    ),
    UserLocation(
      shortName: 'Rajagiriya',
      address: 'Rajagiriya, Colombo District, Western Province, Sri Lanka',
      latitude: 6.9088,
      longitude: 79.8931,
    ),
    UserLocation(
      shortName: 'Kaduwela',
      address: 'Kaduwela, Colombo District, Western Province, Sri Lanka',
      latitude: 6.9333,
      longitude: 79.9833,
    ),
    UserLocation(
      shortName: 'Boralesgamuwa',
      address: 'Boralesgamuwa, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8447,
      longitude: 79.9025,
    ),
    UserLocation(
      shortName: 'Piliyandala',
      address: 'Piliyandala, Colombo District, Western Province, Sri Lanka',
      latitude: 6.8018,
      longitude: 79.9227,
    ),
    UserLocation(
      shortName: 'Gampaha',
      address: 'Gampaha, Western Province, Sri Lanka',
      latitude: 7.0917,
      longitude: 79.9997,
    ),
    UserLocation(
      shortName: 'Negombo',
      address: 'Negombo, Gampaha District, Western Province, Sri Lanka',
      latitude: 7.2083,
      longitude: 79.8358,
    ),
    UserLocation(
      shortName: 'Kadawatha',
      address: 'Kadawatha, Gampaha District, Western Province, Sri Lanka',
      latitude: 7.0016,
      longitude: 79.9507,
    ),
    UserLocation(
      shortName: 'Kiribathgoda',
      address: 'Kiribathgoda, Gampaha District, Western Province, Sri Lanka',
      latitude: 6.9796,
      longitude: 79.9287,
    ),
    UserLocation(
      shortName: 'Kelaniya',
      address: 'Kelaniya, Gampaha District, Western Province, Sri Lanka',
      latitude: 6.9553,
      longitude: 79.9222,
    ),
    UserLocation(
      shortName: 'Wattala',
      address: 'Wattala, Gampaha District, Western Province, Sri Lanka',
      latitude: 6.9897,
      longitude: 79.8917,
    ),
    UserLocation(
      shortName: 'Ja-Ela',
      address: 'Ja-Ela, Gampaha District, Western Province, Sri Lanka',
      latitude: 7.0754,
      longitude: 79.8927,
    ),
    UserLocation(
      shortName: 'Kandy',
      address: 'Kandy, Central Province, Sri Lanka',
      latitude: 7.2906,
      longitude: 80.6337,
    ),
    UserLocation(
      shortName: 'Peradeniya',
      address: 'Peradeniya, Kandy District, Central Province, Sri Lanka',
      latitude: 7.2583,
      longitude: 80.5967,
    ),
    UserLocation(
      shortName: 'Galle',
      address: 'Galle, Southern Province, Sri Lanka',
      latitude: 6.0535,
      longitude: 80.2210,
    ),
    UserLocation(
      shortName: 'Matara',
      address: 'Matara, Southern Province, Sri Lanka',
      latitude: 5.9549,
      longitude: 80.5550,
    ),
    UserLocation(
      shortName: 'Kurunegala',
      address: 'Kurunegala, North Western Province, Sri Lanka',
      latitude: 7.4867,
      longitude: 80.3647,
    ),
    UserLocation(
      shortName: 'Panadura',
      address: 'Panadura, Kalutara District, Western Province, Sri Lanka',
      latitude: 6.7133,
      longitude: 79.9042,
    ),
    UserLocation(
      shortName: 'Kalutara',
      address: 'Kalutara, Western Province, Sri Lanka',
      latitude: 6.5854,
      longitude: 79.9592,
    ),
    UserLocation(
      shortName: 'Ratnapura',
      address: 'Ratnapura, Sabaragamuwa Province, Sri Lanka',
      latitude: 6.7056,
      longitude: 80.3847,
    ),
    UserLocation(
      shortName: 'Anuradhapura',
      address: 'Anuradhapura, North Central Province, Sri Lanka',
      latitude: 8.3114,
      longitude: 80.4037,
    ),
    UserLocation(
      shortName: 'Jaffna',
      address: 'Jaffna, Northern Province, Sri Lanka',
      latitude: 9.6615,
      longitude: 80.0255,
    ),
    UserLocation(
      shortName: 'Batticaloa',
      address: 'Batticaloa, Eastern Province, Sri Lanka',
      latitude: 7.7102,
      longitude: 81.6924,
    ),
    UserLocation(
      shortName: 'Trincomalee',
      address: 'Trincomalee, Eastern Province, Sri Lanka',
      latitude: 8.5874,
      longitude: 81.2152,
    ),
    UserLocation(
      shortName: 'Nuwara Eliya',
      address: 'Nuwara Eliya, Central Province, Sri Lanka',
      latitude: 6.9497,
      longitude: 80.7891,
    ),
  ];

  /// Searches location suggestions with instant local match + online Nominatim/Geocoding query
  static Future<List<UserLocation>> searchSuggestions(
    String query, {
    int limit = 6,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final results = <UserLocation>[];
    final seen = <String>{};

    void addLocation(UserLocation loc) {
      final key =
          '${loc.shortName.toLowerCase()}_${loc.latitude.toStringAsFixed(3)}_${loc.longitude.toStringAsFixed(3)}';
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(loc);
      }
    }

    // 1. Instant local index filtering (0ms latency)
    final lower = clean.toLowerCase();
    for (final loc in popularSriLankanPlaces) {
      if (loc.shortName.toLowerCase().contains(lower) ||
          loc.address.toLowerCase().contains(lower)) {
        addLocation(loc);
      }
    }

    // 2. Fetch online places via OpenStreetMap Nominatim with timeout
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&addressdetails=1&limit=$limit',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TaskBridge-App/1.0 (support@taskbridge.app)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final addr = item['address'] as Map<String, dynamic>?;
            final short =
                addr?['suburb'] ??
                addr?['neighbourhood'] ??
                addr?['road'] ??
                addr?['city'] ??
                addr?['town'] ??
                addr?['village'] ??
                item['name'] ??
                clean;
            final full = item['display_name'] as String? ?? short.toString();
            addLocation(
              UserLocation(
                shortName: short.toString(),
                address: full,
                latitude: lat,
                longitude: lon,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim suggestions error: $e');
    }

    // 3. Native geocoding fallback if few or no results
    if (results.length < 2) {
      try {
        final geocoded = await _geocoding
            .locationFromAddress(clean)
            .timeout(const Duration(seconds: 3));
        for (final g in geocoded.take(3)) {
          final loc = await getAddressFromCoordinates(g.latitude, g.longitude);
          addLocation(loc);
        }
      } catch (_) {}
    }

    return results.take(limit).toList();
  }

  // Forward geocodes a search string into coordinates.
  static Future<UserLocation?> searchLocation(String query) async {
    // Check popular places first
    final clean = query.trim().toLowerCase();
    for (final p in popularSriLankanPlaces) {
      if (p.shortName.toLowerCase() == clean ||
          p.shortName.toLowerCase().startsWith(clean)) {
        return p;
      }
    }

    try {
      final locations = await _geocoding
          .locationFromAddress(query)
          .timeout(const Duration(seconds: 4));
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return await getAddressFromCoordinates(loc.latitude, loc.longitude);
      }
    } catch (e) {
      debugPrint('Forward geocoding native error: $e');
    }

    // Fallback to OpenStreetMap Nominatim if native geocoding failed (common in simulators/iOS)
    return await _fallbackSearchNominatim(query);
  }

  static Future<UserLocation?> _fallbackSearchNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=1',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TaskBridge-App/1.0 (support@taskbridge.app)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final addr = first['address'] as Map<String, dynamic>?;
            final short =
                addr?['suburb'] ??
                addr?['neighbourhood'] ??
                addr?['city'] ??
                addr?['town'] ??
                addr?['village'] ??
                first['name'] ??
                query;
            final full = first['display_name'] as String? ?? short.toString();
            return UserLocation(
              shortName: short.toString(),
              address: full,
              latitude: lat,
              longitude: lon,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim forward geocoding error: $e');
    }
    return null;
  }

  static Future<UserLocation?> _fallbackReverseNominatim(
    double lat,
    double lng,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TaskBridge-App/1.0 (support@taskbridge.app)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        final short =
            addr?['suburb'] ??
            addr?['neighbourhood'] ??
            addr?['city'] ??
            addr?['town'] ??
            addr?['village'] ??
            addr?['road'] ??
            'Selected Location';
        final full = data['display_name'] as String? ?? short.toString();
        return UserLocation(
          shortName: short.toString(),
          address: full,
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocoding error: $e');
    }
    return null;
  }

  // Saves the active location to local preferences.
  static Future<void> saveLocation(UserLocation loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedLocationKey, loc.shortName);
      await prefs.setDouble(_savedLatKey, loc.latitude);
      await prefs.setDouble(_savedLngKey, loc.longitude);
    } catch (_) {}
  }

  // Loads previously saved location if available.
  static Future<UserLocation?> getSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_savedLocationKey);
      final lat = prefs.getDouble(_savedLatKey);
      final lng = prefs.getDouble(_savedLngKey);

      if (name != null && lat != null && lng != null) {
        return UserLocation(
          shortName: name,
          address: name,
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (_) {}
    return null;
  }
}
