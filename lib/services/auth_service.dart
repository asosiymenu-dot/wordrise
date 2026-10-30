import 'dart:async';
import 'dart:convert';



import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/google_auth_config.dart';
import '../models/api_models.dart';
import '../models/session_model.dart';
import 'api_service.dart';

class AuthResponse {
  const AuthResponse({required this.user, required this.token});

  final UserModel user;
  final String token;
}

enum GoogleAuthFailure { configuration, unavailable, missingIdToken }

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.failure);

  final GoogleAuthFailure failure;
}

class AuthService {
  AuthService(this._api);

  final ApiService _api;
  static const _cachedProfileKey = 'wordrise_cached_profile';
  static Future<void>? _googleInitialization;

  bool get googleSignInConfigured => GoogleAuthConfig.isConfigured;

  Stream<AuthResponse> get googleAuthenticationResponses async* {
    if (!GoogleAuthConfig.isConfigured) {
      throw const GoogleAuthException(GoogleAuthFailure.configuration);
    }
    try {
      await _ensureGoogleInitialized();
      GoogleSignIn.instance.attemptLightweightAuthentication();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleAuthException(GoogleAuthFailure.configuration);
      }
      throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    } on Object {
      throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    }

    await for (final event in GoogleSignIn.instance.authenticationEvents) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(user: final account):
          yield await _loginWithGoogleAccount(account);
        case GoogleSignInAuthenticationEventSignOut():
          break;
      }
    }
  }

  Future<String?> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        return '${webBrowserInfo.vendor} ${webBrowserInfo.userAgent}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        return macOsInfo.computerName;
      }
    } catch (_) {}
    return null;
  }

  Future<AuthResponse> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    final deviceName = await _getDeviceName();
    final data = await _api.post('/register.php', {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      if (deviceName != null) 'device_name': deviceName,
    });
    return _persistAuthResponse(data);
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final deviceName = await _getDeviceName();
    final data = await _api.post('/login.php', {
      'identifier': identifier,
      'password': password,
      if (deviceName != null) 'device_name': deviceName,
    });
    return _persistAuthResponse(data);
  }

  Future<AuthResponse?> loginWithGoogle() async {
    if (!GoogleAuthConfig.isConfigured) {
      throw const GoogleAuthException(GoogleAuthFailure.configuration);
    }
    try {
      await _ensureGoogleInitialized();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleAuthException(GoogleAuthFailure.configuration);
      }
      throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    } on Object {
      throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthException(GoogleAuthFailure.unavailable);
    }

    late final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const GoogleAuthException(GoogleAuthFailure.configuration);
        default:
          throw const GoogleAuthException(GoogleAuthFailure.unavailable);
      }
    }

    return _loginWithGoogleAccount(account);
  }

  Future<AuthResponse> _loginWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final idToken = account.authentication.idToken?.trim() ?? '';
    if (idToken.isEmpty) {
      throw const GoogleAuthException(GoogleAuthFailure.missingIdToken);
    }
    final deviceName = await _getDeviceName();
    final data = await _api.post('/google_login.php', {
      'id_token': idToken,
      if (deviceName != null) 'device_name': deviceName,
    }, timeout: const Duration(seconds: 20));
    return _persistAuthResponse(data);
  }

  Future<UserModel> profile() async {
    final data = await _api.get('/profile.php');
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _saveCachedProfile(user);
    return user;
  }

  Future<UserModel> updateProfile({
    required String name,
    required String username,
    required String email,
    String avatar = '',
    String password = '',
  }) async {
    final data = await _api.put('/profile/update.php', {
      'name': name,
      'username': username,
      'email': email,
      'avatar': avatar,
      if (password.trim().isNotEmpty) 'password': password,
    });
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _saveCachedProfile(user);
    return user;
  }

  Future<UserModel> uploadAvatar({
    required List<int> bytes,
    required String mimeType,
  }) async {
    final data = await _api.post('/profile/avatar.php', {
      'image_base64': base64Encode(bytes),
      'mime_type': mimeType,
    });
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _saveCachedProfile(user);
    return user;
  }

  Future<UserModel> deleteAvatar() async {
    final data = await _api.delete('/profile/avatar.php');
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _saveCachedProfile(user);
    return user;
  }

  Future<UserModel?> cachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserModel.fromJson(decoded);
      }
    } on Object {
      await prefs.remove(_cachedProfileKey);
    }
    return null;
  }

  Future<ProfileStatsModel> stats() async {
    final data = await _api.get('/profile/stats.php');
    return ProfileStatsModel.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount() async {
    try {
      await _api.post('/profile/delete.php', {});
    } finally {
      if (GoogleAuthConfig.isConfigured) {
        try {
          await _ensureGoogleInitialized();
          await GoogleSignIn.instance.signOut();
        } on Object {
          // Ignore
        }
      }
      await _api.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedProfileKey);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout.php', {});
    } on Object {
      // Ignore network errors when logging out
    } finally {
      if (GoogleAuthConfig.isConfigured) {
        try {
          await _ensureGoogleInitialized();
          await GoogleSignIn.instance.signOut();
        } on Object {
          // WordRise logout must still complete if the Google provider is unavailable.
        }
      }
      await _api.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedProfileKey);
    }
  }

  Future<void> _saveCachedProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProfileKey, jsonEncode(user.toJson()));
  }

  Future<AuthResponse> _persistAuthResponse(Map<String, dynamic> data) async {
    final token = data['token']?.toString() ?? '';
    final userData = data['user'];
    if (token.isEmpty || userData is! Map<String, dynamic>) {
      throw const ApiException(
        'Serverdan noto‘g‘ri javob keldi. Qayta urinib ko‘ring.',
        type: ApiExceptionType.badResponse,
      );
    }
    final user = UserModel.fromJson(userData);
    await _api.saveToken(token);
    await _saveCachedProfile(user);
    return AuthResponse(user: user, token: token);
  }

  Future<void> _ensureGoogleInitialized() async {
    final initialization = _googleInitialization ??= GoogleSignIn.instance
        .initialize(
          clientId: kIsWeb ? GoogleAuthConfig.webClientId : null,
          serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
        );
    await initialization;
  }

  Future<List<UserSession>> fetchSessions() async {
    final data = await _api.get('/profile/sessions.php');
    if (data != null && data['sessions'] != null) {
      return (data['sessions'] as List)
          .map((s) => UserSession.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> revokeSession(int sessionId) async {
    await _api.post('/profile/revoke_session.php', {
      'session_id': sessionId,
    });
  }
}
