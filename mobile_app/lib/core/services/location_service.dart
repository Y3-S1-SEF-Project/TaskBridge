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

  // Forward geocodes a search string into coordinates.
  static Future<UserLocation?> searchLocation(String query) async {
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
