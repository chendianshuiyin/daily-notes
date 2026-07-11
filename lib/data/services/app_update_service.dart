import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppReleaseAsset {
  const AppReleaseAsset({required this.name, required this.downloadUri});

  final String name;
  final Uri downloadUri;
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.pageUri,
    required this.publishedAt,
    required this.notes,
    required this.assets,
  });

  final String version;
  final Uri pageUri;
  final DateTime? publishedAt;
  final String notes;
  final List<AppReleaseAsset> assets;

  factory AppReleaseInfo.fromGitHubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    final page = Uri.tryParse(json['html_url'] as String? ?? '');
    if (tag is! String || tag.trim().isEmpty || !_isTrustedGitHubUri(page)) {
      throw const FormatException('Release metadata is invalid.');
    }

    final assets = <AppReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final item in rawAssets.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final name = map['name'];
        final uri = Uri.tryParse(map['browser_download_url'] as String? ?? '');
        if (name is String && _isTrustedGitHubUri(uri)) {
          assets.add(AppReleaseAsset(name: name, downloadUri: uri!));
        }
      }
    }

    return AppReleaseInfo(
      version: tag.trim().replaceFirst(RegExp(r'^[vV]'), ''),
      pageUri: page!,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      notes: (json['body'] as String? ?? '').trim(),
      assets: List.unmodifiable(assets),
    );
  }

  Uri updateUriForCurrentPlatform() {
    if (kIsWeb) return pageUri;
    final matcher = switch (defaultTargetPlatform) {
      TargetPlatform.android => (String name) => name.endsWith('.apk'),
      TargetPlatform.windows =>
        (String name) => name.contains('windows') && name.endsWith('.zip'),
      TargetPlatform.linux =>
        (String name) => name.contains('linux') && name.endsWith('.zip'),
      _ => (String name) => false,
    };
    for (final asset in assets) {
      if (matcher(asset.name.toLowerCase())) return asset.downloadUri;
    }
    return pageUri;
  }

  static bool isNewer(String candidate, String current) {
    return _Version.parse(candidate).compareTo(_Version.parse(current)) > 0;
  }
}

abstract class AppUpdateClient {
  Future<String> currentVersion();
  Future<AppReleaseInfo> fetchLatest();
  Future<bool> openUpdate(AppReleaseInfo release);
}

class AppUpdateService implements AppUpdateClient {
  AppUpdateService({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ),
          );

  static final Uri latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/chendianshuiyin/daily-notes/releases/latest',
  );

  final Dio _client;

  @override
  Future<String> currentVersion() async {
    return (await PackageInfo.fromPlatform()).version;
  }

  @override
  Future<AppReleaseInfo> fetchLatest() async {
    final response = await _client.getUri<Object?>(latestReleaseUri);
    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw const FormatException('Latest release response is invalid.');
    }
    return AppReleaseInfo.fromGitHubJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<bool> openUpdate(AppReleaseInfo release) async {
    final uri = release.updateUriForCurrentPlatform();
    if (!_isTrustedGitHubUri(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.parts, this.isPrerelease);

  final List<int> parts;
  final bool isPrerelease;

  factory _Version.parse(String source) {
    final normalized = source.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = normalized.split('+').first;
    final segments = core.split('-');
    final parts = segments.first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return _Version(parts, segments.length > 1);
  }

  @override
  int compareTo(_Version other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var index = 0; index < length; index++) {
      final left = index < parts.length ? parts[index] : 0;
      final right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) return left.compareTo(right);
    }
    if (isPrerelease == other.isPrerelease) return 0;
    return isPrerelease ? -1 : 1;
  }
}

bool _isTrustedGitHubUri(Uri? uri) {
  if (uri == null || uri.scheme != 'https') return false;
  return uri.host == 'github.com' || uri.host.endsWith('.github.com');
}
