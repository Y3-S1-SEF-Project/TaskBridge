import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central API and environment configuration.
/// Dynamically loads all values from the `.env` file with NO hardcoded secrets in code.
class ApiConfig {
  ApiConfig._();

  static final Map<String, String> _env = {};
  static bool _initialized = false;

  /// Loads and parses the `.env` file bundled with the app.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final content = await rootBundle.loadString('.env');
      for (final rawLine in const LineSplitter().convert(content)) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final eqIndex = line.indexOf('=');
        if (eqIndex > 0) {
          final key = line.substring(0, eqIndex).trim();
          var value = line.substring(eqIndex + 1).trim();

          // Strip quotes if wrapped
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            if (value.length >= 2) {
              value = value.substring(1, value.length - 1);
            }
          }
          _env[key] = value;
        }
      }
      _initialized = true;
      if (kDebugMode) {
        debugPrint(
          ' [ApiConfig] Loaded .env (${_env.length} vars). Base URL: $baseUrl',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [ApiConfig] Note: .env file not found or could not be loaded: $e',
        );
      }
      _initialized = true;
    }
  }

  /// Retrieves any variable from .env or compile-time flags.
  static String get(String key, {String fallback = ''}) {
    // 1. Build-time override (--dart-define)
    final fromDartDefine = String.fromEnvironment(key);
    if (fromDartDefine.isNotEmpty) return fromDartDefine;

    // 2. Read from .env
    final value = _env[key];
    if (value != null && value.isNotEmpty) return value;

    // 3. Fallback
    return fallback;
  }

  static String? _resolvedBaseUrl;

  /// Whether a live, verified working base URL has been discovered.
  static bool get hasWorkingBaseUrl =>
      _resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty;

  /// Updates the verified working base URL so all services can reuse it.
  static void setWorkingBaseUrl(String url) {
    if (url.isNotEmpty && _resolvedBaseUrl != url) {
      _resolvedBaseUrl = url;
      debugPrint(' [ApiConfig] Working base URL locked to: $url');
    }
  }

  /// Active backend API Base URL read from .env (or dynamically verified working URL)
  static String get baseUrl {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    return get('API_BASE_URL', fallback: 'http://13.60.35.78');
  }

  /// Candidate URLs for connection probing read from .env
  static List<String> get candidateUrls {
    final list = <String>[];
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      list.add(_resolvedBaseUrl!);
    }

    final envBase = get('API_BASE_URL');
    if (envBase.isNotEmpty && !list.contains(envBase)) {
      list.add(envBase);
    }

    final raw = get('API_CANDIDATE_URLS');
    if (raw.isNotEmpty) {
      for (final item in raw.split(',')) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && !list.contains(trimmed)) {
          list.add(trimmed);
        }
      }
    }

    // Always include standard fallbacks: AWS EC2 server, Android emulator loopback, Mac IP, localhost
    const fallbacks = [
      'http://13.60.35.78',
      'http://10.0.2.2:5298',
      'http://192.168.1.12:5298',
      'http://localhost:5298',
      'http://127.0.0.1:5298',
    ];
    for (final fb in fallbacks) {
      if (!list.contains(fb)) {
        list.add(fb);
      }
    }

    return list;
  }

  /// Google Maps API Key loaded strictly from .env (no hardcoded secrets in code)
  static String get googleMapsApiKey => get('GOOGLE_MAPS_API_KEY');

  /// Cloudflare R2 Public Media Bucket URL loaded from .env
  static String get r2PublicUrl => get('CLOUDFLARE_R2_PUBLIC_URL');

  /// Environment name (development, staging, production)
  static String get environment => get('ENVIRONMENT', fallback: 'development');
}
