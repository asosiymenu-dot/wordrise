class AppReleaseModel {
  const AppReleaseModel({
    required this.platform,
    required this.versionName,
    required this.versionCode,
    required this.minSupportedVersionCode,
    required this.downloadUrl,
    required this.isRequired,
    this.releaseNotes,
    this.sha256,
    this.fileSizeBytes,
    this.publishedAt,
  });

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    return AppReleaseModel(
      platform: json['platform']?.toString() ?? 'android',
      versionName: json['version_name']?.toString() ?? '',
      versionCode: _asInt(json['version_code']),
      minSupportedVersionCode: _asInt(
        json['min_supported_version_code'],
        fallback: 1,
      ),
      downloadUrl: json['download_url']?.toString() ?? '',
      isRequired: _asBool(json['is_required']),
      releaseNotes: _nullableString(json['release_notes']),
      sha256: _nullableString(json['sha256']),
      fileSizeBytes: _nullableInt(json['file_size_bytes']),
      publishedAt: DateTime.tryParse(
        json['published_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  final String platform;
  final String versionName;
  final int versionCode;
  final int minSupportedVersionCode;
  final String downloadUrl;
  final bool isRequired;
  final String? releaseNotes;
  final String? sha256;
  final int? fileSizeBytes;
  final DateTime? publishedAt;

  bool requiresUpdateFrom(int currentVersionCode) {
    if (versionCode <= currentVersionCode) return false;
    return isRequired || currentVersionCode < minSupportedVersionCode;
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'version_name': versionName,
      'version_code': versionCode,
      'min_supported_version_code': minSupportedVersionCode,
      'download_url': downloadUrl,
      'is_required': isRequired,
      'release_notes': releaseNotes,
      'sha256': sha256,
      'file_size_bytes': fileSizeBytes,
      'published_at': publishedAt?.toUtc().toIso8601String(),
    };
  }
}

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.currentVersionCode,
    required this.updateAvailable,
    required this.forceUpdate,
    this.release,
    this.fromCache = false,
  });

  final int currentVersionCode;
  final bool updateAvailable;
  final bool forceUpdate;
  final AppReleaseModel? release;
  final bool fromCache;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  final parsed = _asInt(value, fallback: -1);
  return parsed < 0 ? null : parsed;
}

bool _asBool(Object? value) {
  return value == true || value == 1 || value?.toString() == '1';
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
