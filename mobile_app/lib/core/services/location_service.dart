import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UserLocation {
  final String shortName;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;

  const UserLocation({
    required this.shortName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
  });

  Map<String, dynamic> toJson() => {
    'shortName': shortName,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    if (placeId != null) 'placeId': placeId,
  };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    shortName: LocationService.cleanLocationName(
      json['shortName'] as String? ?? 'Colombo',
    ),
    address: LocationService.cleanLocationName(
      json['address'] as String? ?? 'Colombo, Sri Lanka',
    ),
    latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 79.8612,
    placeId: json['placeId'] as String?,
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

  /// Checks whether a given string is or contains a Google Plus Code / Open Location Code
  /// (e.g. "VW2C+CFP", "6PH57VP3+PR")
  static bool isPlusCode(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    return RegExp(
      r'\b[A-Za-z0-9]{2,8}\+[A-Za-z0-9]{1,4}\b',
      caseSensitive: false,
    ).hasMatch(clean);
  }

  /// Cleans navigation codes / Google Plus codes (e.g. "VW2C+CFP") from location and address strings.
  static String cleanLocationName(String text) {
    if (text.isEmpty) return text;
    // Strip Google Plus Codes (e.g. VW2C+CFP, 6PH57VP3+PR)
    String cleaned = text.replaceAll(
      RegExp(r'\b[A-Za-z0-9]{2,8}\+[A-Za-z0-9]{1,4}\b', caseSensitive: false),
      '',
    );
    // Collapse multiple commas and surrounding whitespace
    cleaned = cleaned.replaceAll(RegExp(r'(\s*,\s*)+'), ', ');
    cleaned = cleaned.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned.trim();
  }

  /// Combines street address and city/suburb nicely, avoiding duplicate names or plus codes.
  static String formatDisplayAddress(String? address, String? location) {
    final cleanAddr = cleanLocationName(address ?? '');
    final cleanLoc = cleanLocationName(location ?? '');

    if (cleanAddr.isEmpty && cleanLoc.isEmpty) return '';
    if (cleanAddr.isEmpty) return cleanLoc;
    if (cleanLoc.isEmpty) return cleanAddr;

    if (cleanAddr.toLowerCase().contains(cleanLoc.toLowerCase())) {
      return cleanAddr;
    }
    return '$cleanAddr, $cleanLoc';
  }

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

        // Build clean short name (e.g., "Colombo 05" or "Maharagama")
        // Always prioritize real city/suburb names and NEVER use Plus Codes
        String short = '';
        if (place.subLocality != null &&
            place.subLocality!.isNotEmpty &&
            !isPlusCode(place.subLocality!)) {
          short = place.subLocality!;
        } else if (place.locality != null &&
            place.locality!.isNotEmpty &&
            !isPlusCode(place.locality!)) {
          short = place.locality!;
        } else if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty &&
            !isPlusCode(place.subAdministrativeArea!)) {
          short = place.subAdministrativeArea!;
        } else if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty &&
            !isPlusCode(place.administrativeArea!)) {
          short = place.administrativeArea!;
        } else if (place.name != null &&
            place.name!.isNotEmpty &&
            !isPlusCode(place.name!)) {
          short = place.name!;
        } else {
          short = 'Selected Area';
        }

        short = cleanLocationName(short);
        if (short.isEmpty) short = 'Selected Area';

        // Build descriptive full address without Plus Codes or duplicate parts
        final parts = <String>[];
        void maybeAdd(String? val) {
          if (val == null || val.trim().isEmpty) return;
          final cleaned = cleanLocationName(val);
          if (cleaned.isNotEmpty &&
              !isPlusCode(cleaned) &&
              !parts.any((p) => p.toLowerCase() == cleaned.toLowerCase())) {
            parts.add(cleaned);
          }
        }

        if (place.name != null && place.name != short) {
          maybeAdd(place.name);
        }
        maybeAdd(place.street);
        maybeAdd(place.subLocality);
        maybeAdd(place.locality);
        maybeAdd(place.subAdministrativeArea);
        maybeAdd(place.administrativeArea);
        maybeAdd(place.country);

        final full = parts.isEmpty ? short : parts.join(', ');

        return UserLocation(
          shortName: short,
          address: cleanLocationName(full),
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

  static String get _googleApiKey {
    final key = ApiConfig.googleMapsApiKey;
    if (key.isNotEmpty) return key;
    return 'AIzaSyBF12uONPYPGW6FFizwyficdIoPIasZz6s';
  }

  /// Live Google Places Autocomplete search across Sri Lanka (no hardcoded lists)
  static Future<List<UserLocation>> searchSuggestions(
    String query, {
    int limit = 6,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final apiKey = _googleApiKey;
    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
          'input=${Uri.encodeComponent(clean)}'
          '&components=country:lk'
          '&key=$apiKey',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final predictions = data['predictions'] as List?;
          if (predictions != null && predictions.isNotEmpty) {
            final results = <UserLocation>[];
            for (final p in predictions.take(limit)) {
              final placeId = p['place_id'] as String?;
              final formatting =
                  p['structured_formatting'] as Map<String, dynamic>?;
              final mainText =
                  formatting?['main_text'] as String? ??
                  p['description'] as String? ??
                  clean;
              final secondaryText =
                  formatting?['secondary_text'] as String? ?? '';
              final fullAddress = secondaryText.isNotEmpty
                  ? '$mainText, $secondaryText'
                  : mainText;

              results.add(
                UserLocation(
                  shortName: cleanLocationName(mainText),
                  address: cleanLocationName(fullAddress),
                  latitude: 0.0,
                  longitude: 0.0,
                  placeId: placeId,
                ),
              );
            }
            if (results.isNotEmpty) return results;
          }
        }
      } catch (e) {
        debugPrint('Google Places Autocomplete error: $e');
      }
    }

    // Fallback 1: Native device geocoder
    try {
      final geocoded = await _geocoding
          .locationFromAddress('$clean, Sri Lanka')
          .timeout(const Duration(seconds: 3));
      final results = <UserLocation>[];
      for (final g in geocoded.take(limit)) {
        final loc = await getAddressFromCoordinates(g.latitude, g.longitude);
        results.add(loc);
      }
      if (results.isNotEmpty) return results;
    } catch (_) {}

    // Fallback 2: OpenStreetMap Nominatim
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
        final results = <UserLocation>[];
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
            results.add(
              UserLocation(
                shortName: cleanLocationName(short.toString()),
                address: cleanLocationName(full),
                latitude: lat,
                longitude: lon,
              ),
            );
          }
        }
        if (results.isNotEmpty) return results;
      }
    } catch (_) {}

    return [];
  }

  /// Fetches precise coordinates and address details for a Google Place ID
  static Future<UserLocation?> getPlaceDetails(String placeId) async {
    final apiKey = _googleApiKey;
    if (apiKey.isEmpty || placeId.isEmpty) return null;

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&fields=geometry,name,formatted_address'
        '&key=$apiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          final geom = result['geometry'] as Map<String, dynamic>?;
          final loc = geom?['location'] as Map<String, dynamic>?;
          final lat = (loc?['lat'] as num?)?.toDouble();
          final lng = (loc?['lng'] as num?)?.toDouble();
          final name = result['name'] as String? ?? '';
          final formatted = result['formatted_address'] as String? ?? name;

          if (lat != null && lng != null) {
            return UserLocation(
              shortName: cleanLocationName(name.isNotEmpty ? name : formatted),
              address: cleanLocationName(formatted),
              latitude: lat,
              longitude: lng,
              placeId: placeId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Google Place Details error: $e');
    }
    return null;
  }

  // Forward geocodes a search string into coordinates via Google Geocoding API.
  static Future<UserLocation?> searchLocation(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final apiKey = _googleApiKey;
    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?'
          'address=${Uri.encodeComponent(clean)}'
          '&components=country:LK'
          '&key=$apiKey',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final geom = first['geometry'] as Map<String, dynamic>?;
            final loc = geom?['location'] as Map<String, dynamic>?;
            final lat = (loc?['lat'] as num?)?.toDouble();
            final lng = (loc?['lng'] as num?)?.toDouble();
            final formatted = first['formatted_address'] as String? ?? clean;
            final placeId = first['place_id'] as String?;

            if (lat != null && lng != null) {
              return UserLocation(
                shortName: cleanLocationName(formatted.split(',').first.trim()),
                address: cleanLocationName(formatted),
                latitude: lat,
                longitude: lng,
                placeId: placeId,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Google Geocode error: $e');
      }
    }

    try {
      final locations = await _geocoding
          .locationFromAddress('$clean, Sri Lanka')
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
        final rawShort =
            addr?['suburb'] ??
            addr?['neighbourhood'] ??
            addr?['city'] ??
            addr?['town'] ??
            addr?['village'] ??
            addr?['road'] ??
            'Selected Location';
        final rawFull = data['display_name'] as String? ?? rawShort.toString();
        final short = cleanLocationName(rawShort.toString());
        final full = cleanLocationName(rawFull);
        return UserLocation(
          shortName: short.isNotEmpty ? short : 'Selected Location',
          address: full.isNotEmpty ? full : short,
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
      await prefs.setString(
        _savedLocationKey,
        cleanLocationName(loc.shortName),
      );
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
        final clean = cleanLocationName(name);
        return UserLocation(
          shortName: clean.isNotEmpty ? clean : 'Colombo',
          address: clean.isNotEmpty ? clean : 'Colombo',
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (_) {}
    return null;
  }
}
