import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_model.dart';
import 'api_service.dart';

class AppUpdateService {
  AppUpdateService(this._api);

  static const _cachedReleaseKey = 'wordrise_cached_app_release';

  final ApiService _api;

  Future<AppUpdateDecision> check({required String locale}) async {
    if (kIsWeb || kDebugMode) {
      return const AppUpdateDecision(
        currentVersionCode: 0,
        updateAvailable: false,
        forceUpdate: false,
      );
    }
    var currentVersionCode = 0;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersionCode = _versionCode(packageInfo.buildNumber);
    } on Object {
      return const AppUpdateDecision(
        currentVersionCode: 0,
        updateAvailable: false,
        forceUpdate: false,
      );
    }

    try {
      final data = await _api.get(
        '/app/version.php',
        query: {
          'platform': 'android',
          'current_version_code': currentVersionCode.toString(),
          'locale': locale,
        },
        timeout: const Duration(seconds: 5),
      );
      final release = _releaseFrom(data['release']);
      final prefs = await SharedPreferences.getInstance();
      if (release == null) {
        await prefs.remove(_cachedReleaseKey);
      } else {
        await prefs.setString(_cachedReleaseKey, jsonEncode(release.toJson()));
      }
      final updateAvailable =
          _asBool(data['update_available']) ||
          (release?.versionCode ?? 0) > currentVersionCode;
      final forceUpdate =
          updateAvailable &&
          (_asBool(data['force_update']) ||
              (release?.requiresUpdateFrom(currentVersionCode) ?? false));
      return AppUpdateDecision(
        currentVersionCode: currentVersionCode,
        updateAvailable: updateAvailable,
        forceUpdate: forceUpdate,
        release: release,
      );
    } on Object {
      return _cachedDecision(currentVersionCode);
    }
  }

  Future<bool> openDownload(AppReleaseModel release) async {
    final uri = Uri.tryParse(release.downloadUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<AppUpdateDecision> _cachedDecision(int currentVersionCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedReleaseKey);
    if (raw == null || raw.isEmpty) {
      return AppUpdateDecision(
        currentVersionCode: currentVersionCode,
        updateAvailable: false,
        forceUpdate: false,
        fromCache: true,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      final release = _releaseFrom(decoded);
      final available =
          release != null && release.versionCode > currentVersionCode;
      return AppUpdateDecision(
        currentVersionCode: currentVersionCode,
        updateAvailable: available,
        forceUpdate:
            available && release.requiresUpdateFrom(currentVersionCode),
        release: release,
        fromCache: true,
      );
    } on Object {
      await prefs.remove(_cachedReleaseKey);
      return AppUpdateDecision(
        currentVersionCode: currentVersionCode,
        updateAvailable: false,
        forceUpdate: false,
        fromCache: true,
      );
    }
  }
}

AppReleaseModel? _releaseFrom(Object? value) {
  if (value is Map<String, dynamic>) {
    return AppReleaseModel.fromJson(value);
  }
  if (value is Map) {
    return AppReleaseModel.fromJson(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }
  return null;
}

int _versionCode(String buildNumber) {
  final direct = int.tryParse(buildNumber.trim());
  if (direct != null) return direct;
  final match = RegExp(r'\d+').firstMatch(buildNumber);
  return int.tryParse(match?.group(0) ?? '') ?? 0;
}

bool _asBool(Object? value) {
  return value == true || value == 1 || value?.toString() == '1';
}
