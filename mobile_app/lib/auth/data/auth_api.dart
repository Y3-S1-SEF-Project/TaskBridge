import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _tokenKey = 'taskbridge.token';
  static const _userKey = 'taskbridge.user';
  static const _configuredUrl = String.fromEnvironment('TASKBRIDGE_API_URL');
  static String? _workingBaseUrl;
  String? _token;

  List<String> get _candidateUrls {
    if (_configuredUrl.isNotEmpty) return [_configuredUrl];
    if (!kDebugMode) return const [''];
    if (_workingBaseUrl != null) return [_workingBaseUrl!];

    // Priority 1: localhost (works instantly for USB-connected real phone with adb reverse & desktop)
    // Priority 2: 10.0.2.2 (works on Android emulator)
    // Priority 3: Mac LAN Wi-Fi IP (works for real mobile on same Wi-Fi)
    return const [
      'http://localhost:5298',
      'http://10.0.2.2:5298',
      'http://192.168.1.4:5298',
      'http://192.168.1.2:5298',
    ];
  }

  Uri get base {
    final url =
        _workingBaseUrl ??
        (_configuredUrl.isNotEmpty
            ? _configuredUrl
            : kDebugMode
            ? 'http://localhost:5298'
            : '');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        (!kDebugMode && uri.scheme != 'https')) {
      throw const AuthException(
        'Set a valid HTTPS TASKBRIDGE_API_URL for this app.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    bool get = false,
  }) async {
    final candidates = _candidateUrls;
    Exception? lastNetworkError;

    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final baseUri = Uri.tryParse(candidate);
      if (baseUri == null || !baseUri.hasAuthority) continue;

      try {
        final uri = baseUri.resolve('/api/auth/$path');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        };
        // Short timeout during discovery if candidate isn't proven yet
        final isProven = _workingBaseUrl != null || candidates.length == 1;
        final timeout = isProven
            ? const Duration(seconds: 25)
            : const Duration(seconds: 3);

        final response =
            await (get
                    ? _client.get(uri, headers: headers)
                    : _client.post(
                        uri,
                        headers: headers,
                        body: jsonEncode(body ?? {}),
                      ))
                .timeout(timeout);

        // Success connecting to this host!
        _workingBaseUrl = candidate;

        Map<String, dynamic> data = {};
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) data = decoded;
          } on FormatException {
            /* Non-JSON upstream errors use the fallback below. */
          }
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final errors = data['errors'];
          final validation = errors is Map
              ? errors.values.expand((v) => v is List ? v : [v]).join(' ')
              : null;
          throw AuthException(
            (data['detail'] as String?) ??
                (data['message'] as String?) ??
                validation ??
                (response.statusCode == 429
                    ? 'Too many attempts. Please wait and try again.'
                    : response.statusCode == 401
                    ? 'Your session has expired. Please log in again.'
                    : 'Unable to complete the request. Please try again.'),
            status: response.statusCode,
          );
        }
        return data;
      } on AuthException {
        rethrow;
      } catch (e) {
        lastNetworkError = e is Exception ? e : Exception(e.toString());
        if (i < candidates.length - 1) continue;
      }
    }

    if (lastNetworkError is TimeoutException) {
      throw const AuthException(
        'The request timed out. Check your connection and try again.',
      );
    }
    throw const AuthException(
      'Cannot reach TaskBridge. Check your connection and the API address.',
    );
  }

  // Registers a new user and sends email OTP.
  Future<OtpChallenge> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    final result = await _request(
      'register',
      body: {
        'fullName': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
      },
    );
    return OtpChallenge.fromJson(result);
  }

  // Verifies the email OTP and stores the session in shared_preferences.
  Future<({AuthUser user, bool isNewUser})> verifyEmailOtp(
    String email,
    String code,
  ) async {
    final result = await _request(
      'verify-otp',
      body: {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );

    final token = result['accessToken'] as String;
    final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
    final isNewUser = (result['isNewUser'] as bool?) ?? true;

    await _saveSession(token, user);
    return (user: user, isNewUser: isNewUser);
  }

  // Resends an OTP to the given email.
  Future<OtpChallenge> resendOtp(String email) async {
    final result = await _request(
      'resend-otp',
      body: {'email': email.trim().toLowerCase()},
    );
    return OtpChallenge.fromJson(result);
  }

  // Logs in using email or phone + password.
  Future<({AuthUser user, bool isNewUser})> login(
    String identifier,
    String password,
  ) async {
    final result = await _request(
      'login',
      body: {'identifier': identifier.trim(), 'password': password},
    );

    final token = result['accessToken'] as String;
    final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
    final isNewUser = (result['isNewUser'] as bool?) ?? false;

    await _saveSession(token, user);
    return (user: user, isNewUser: isNewUser);
  }

  // Starts password recovery using email.
  Future<OtpChallenge> forgot(String email) async {
    final result = await _request(
      'forgot-password',
      body: {'email': email.trim().toLowerCase()},
    );
    return OtpChallenge.fromJson(result);
  }

  // Resets password using the verification code.
  Future<void> reset(
    String challengeId,
    String resetToken,
    String password,
  ) async {
    await _request(
      'reset-password',
      body: {
        'email': challengeId.trim().toLowerCase(),
        'code': resetToken.trim(),
        'newPassword': password,
      },
    );
  }

  // Updates profile information (Address, Location, Preferences, Photo) from screen C08.
  Future<AuthUser> updateProfile({
    String? fullName,
    String? address,
    String? location,
    String? preferences,
    String? profilePhotoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (address != null) body['address'] = address;
    if (location != null) body['location'] = location;
    if (preferences != null) body['preferences'] = preferences;
    if (profilePhotoUrl != null) body['profilePhotoUrl'] = profilePhotoUrl;

    final result = await _request('profile', body: body);

    final user = AuthUser.fromJson(result);
    if (_token != null) {
      await _saveSession(_token!, user);
    }
    return user;
  }

  Future<AuthUser> _uploadFile(
    String path,
    String filePath, {
    String? userId,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    }

    final candidates = _candidateUrls;
    Exception? lastError;

    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final baseUri = Uri.tryParse(candidate);
      if (baseUri == null || !baseUri.hasAuthority) continue;

      try {
        final uri = baseUri.resolve('/api/auth/$path');
        final request = http.MultipartRequest('POST', uri);

        if (_token != null && _token!.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $_token';
        }
        if (userId != null && userId.isNotEmpty) {
          request.fields['userId'] = userId;
        }

        final multipartFile = await http.MultipartFile.fromPath(
          'file',
          filePath,
        );
        request.files.add(multipartFile);

        final isProven = _workingBaseUrl != null || candidates.length == 1;
        final timeout = isProven
            ? const Duration(seconds: 40)
            : const Duration(seconds: 4);

        final streamedResponse = await _client.send(request).timeout(timeout);
        final response = await http.Response.fromStream(streamedResponse);

        _workingBaseUrl = candidate;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final updatedUser = AuthUser.fromJson(json);
          if (_token != null) {
            await _saveSession(_token!, updatedUser);
          }
          return updatedUser;
        } else {
          String message = 'Failed to upload.';
          try {
            final err = jsonDecode(response.body);
            message =
                err['detail'] ?? err['title'] ?? err['message'] ?? message;
          } catch (_) {}
          throw AuthException(
            '$message (HTTP ${response.statusCode})',
            status: response.statusCode,
          );
        }
      } on AuthException {
        rethrow;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < candidates.length - 1) continue;
      }
    }

    throw AuthException(
      'Failed to upload file: ${lastError ?? "Cannot reach server"}',
    );
  }

  // Uploads a profile picture file to Cloudflare R2 and updates user profile.
  Future<AuthUser> uploadProfilePhoto(String filePath, {String? userId}) async {
    return _uploadFile('profile/photo', filePath, userId: userId);
  }

  // Sets up or updates the user's provider profile and activates provider mode.
  Future<AuthUser> saveProviderProfile({
    String? category,
    String? skills,
    String? services,
    String? experience,
    String? certifications,
    String? serviceAreas,
    String? availability,
    String? bio,
    String? location,
    double? hourlyRate,
  }) async {
    final body = <String, dynamic>{};
    if (category != null) body['category'] = category;
    if (skills != null) body['skills'] = skills;
    if (services != null) body['services'] = services;
    if (experience != null) body['experience'] = experience;
    if (certifications != null) body['certifications'] = certifications;
    if (serviceAreas != null) body['serviceAreas'] = serviceAreas;
    if (availability != null) body['availability'] = availability;
    if (bio != null) body['bio'] = bio;
    if (location != null) body['location'] = location;
    if (hourlyRate != null) body['hourlyRate'] = hourlyRate;

    final result = await _request('provider/setup', body: body);
    final user = AuthUser.fromJson(result);
    if (_token != null) {
      await _saveSession(_token!, user);
    }
    return user;
  }

  // Uploads a certification document or photo to Cloudflare R2.
  Future<AuthUser> uploadCertification(
    String filePath, {
    String? userId,
  }) async {
    return _uploadFile('provider/certification', filePath, userId: userId);
  }

  // Restores user session from shared_preferences on splash screen.
  Future<AuthUser?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (_token == null) return null;

    AuthUser? cachedUser;
    if (userJson != null) {
      try {
        cachedUser = AuthUser.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }

    // Verify token with backend /api/auth/me
    try {
      final me = await _request('me', get: true);
      final verifiedUser = AuthUser.fromJson(me);
      await _saveSession(_token!, verifiedUser);
      return verifiedUser;
    } on AuthException catch (e) {
      if (e.status == 401) {
        await clearSession();
        return null;
      }
      return cachedUser;
    } catch (_) {
      return cachedUser;
    }
  }

  // Revokes the current server session and clears shared_preferences.
  Future<void> logout() async {
    try {
      await _request('logout');
    } catch (_) {}
    await clearSession();
  }

  // Clears shared_preferences session keys.
  Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Saves session token and user profile into shared_preferences.
  Future<void> _saveSession(String token, AuthUser user) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  void dispose() => _client.close();
}
