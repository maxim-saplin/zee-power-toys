import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:package_info_plus/package_info_plus.dart';
import 'install_targets.dart';
import 'installer.dart';
import 'release_compare.dart';

/// Result of probing GitHub Releases for a Zee Power Toys APK.
sealed class AppUpdateCheck {
  const AppUpdateCheck();
}

/// Published Latest found but no installable APK asset (rare).
class AppUpdateUpToDate extends AppUpdateCheck {
  const AppUpdateUpToDate({required this.installedCode});
  final int installedCode;
}

/// Remote versionCode **>** installed → Update.
class AppUpdateAvailable extends AppUpdateCheck {
  const AppUpdateAvailable({
    required this.installedCode,
    required this.remoteCode,
    required this.remoteLabel,
    required this.asset,
  });

  final int installedCode;
  final int remoteCode;
  final String remoteLabel;
  final GithubAsset asset;
}

/// Remote versionCode **==** installed → Reinstall same Latest asset (0103).
class AppUpdateReinstall extends AppUpdateCheck {
  const AppUpdateReinstall({
    required this.installedCode,
    required this.remoteCode,
    required this.remoteLabel,
    required this.asset,
  });

  final int installedCode;
  final int remoteCode;
  final String remoteLabel;
  final GithubAsset asset;
}

/// Installed code **>** Latest published → lab tip ahead; soft Reinstall Release (0103).
class AppUpdateTipAhead extends AppUpdateCheck {
  const AppUpdateTipAhead({
    required this.installedCode,
    required this.remoteCode,
    required this.remoteLabel,
    required this.asset,
  });

  final int installedCode;
  final int remoteCode;
  final String remoteLabel;
  final GithubAsset asset;
}

class AppUpdateNonePublished extends AppUpdateCheck {
  const AppUpdateNonePublished();
}

class AppUpdateCheckFailed extends AppUpdateCheck {
  const AppUpdateCheckFailed(this.message);
  final String message;
}

/// Parses `1.0.0+3` / `v1.0.0+3` / bare `+3` from a release tag or name.
int? parseVersionCode(String raw) {
  final text = raw.trim();
  final plus = RegExp(r'\+(\d+)\s*$').firstMatch(text);
  if (plus != null) {
    return int.tryParse(plus.group(1)!);
  }
  final bare = RegExp(r'^v?\d+\.\d+\.\d+$').firstMatch(text);
  if (bare != null) {
    // Tag without +BUILD — treat as code 0 (never newer than a +N build).
    return 0;
  }
  return null;
}

GithubAsset? pickApkAsset({
  required String repo,
  required String tag,
  required List<Map<String, dynamic>> assets,
  List<String> preferredNames = kSelfUpdateAssetNames,
}) {
  Map<String, dynamic>? chosen;
  for (final name in preferredNames) {
    for (final a in assets) {
      if (a['name'] == name) {
        chosen = a;
        break;
      }
    }
    if (chosen != null) break;
  }
  if (chosen == null) {
    for (final a in assets) {
      final n = a['name'] as String? ?? '';
      if (n.toLowerCase().endsWith('.apk')) {
        chosen = a;
        break;
      }
    }
  }
  if (chosen == null) return null;
  final url = chosen['browser_download_url'] as String? ?? '';
  final name = chosen['name'] as String? ?? 'app-release.apk';
  if (url.isEmpty) return null;
  return GithubAsset(
    repo: repo,
    branch: 'main',
    path: name,
    releaseTag: tag,
    directUrl: url,
  );
}

class _LatestRelease {
  const _LatestRelease({
    required this.code,
    required this.label,
    required this.asset,
  });
  final int code;
  final String label;
  final GithubAsset asset;
}

/// Fetches public releases and returns Update / Reinstall / tip-ahead.
/// Soft network budget for GH Releases probe (0115 — don't hang forever).
const Duration kAppSelfUpdateTimeout = Duration(seconds: 15);

/// Injectable Toys version check (0115 auto on Install open; tests stub this).
typedef AppUpdateChecker = Future<AppUpdateCheck> Function();

class AppSelfUpdate {
  AppSelfUpdate({
    http.Client? client,
    this.repo = kSelfUpdateRepo,
    int? installedCode,
    this.apiBase = 'https://api.github.com',
    this.timeout = kAppSelfUpdateTimeout,
  })  : _installedCodeOverride = installedCode,
        _client = client ?? http.Client();

  final http.Client _client;
  final String repo;
  final int? _installedCodeOverride;
  final String apiBase;
  final Duration timeout;

  Future<int> _installedCode() async {
    final override = _installedCodeOverride;
    if (override != null) return override;
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<AppUpdateCheck> check() async {
    final installedCode = await _installedCode();
    final uri = Uri.parse('$apiBase/repos/$repo/releases?per_page=10');
    try {
      final res = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        return AppUpdateCheckFailed('GitHub HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body);
      if (body is! List) {
        return const AppUpdateCheckFailed('Unexpected releases payload');
      }

      _LatestRelease? latest;
      var sawPublished = false;

      for (final item in body) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if (map['draft'] == true) continue;
        sawPublished = true;
        if (map['prerelease'] == true) continue;

        final tag = (map['tag_name'] as String?) ?? '';
        final name = (map['name'] as String?) ?? '';
        final code = parseVersionCode(tag) ?? parseVersionCode(name);
        if (code == null) continue;

        final rawAssets = map['assets'];
        if (rawAssets is! List) continue;
        final assets = rawAssets
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final asset = pickApkAsset(repo: repo, tag: tag, assets: assets);
        if (asset == null) continue;

        final label = tag.isNotEmpty ? tag : name;
        final candidate = _LatestRelease(code: code, label: label, asset: asset);
        if (latest == null || candidate.code > latest.code) {
          latest = candidate;
        }
      }

      if (latest == null) {
        if (!sawPublished) return const AppUpdateNonePublished();
        return AppUpdateUpToDate(installedCode: installedCode);
      }

      switch (compareVersionCodes(installedCode, latest.code)) {
        case VersionRelation.older:
          return AppUpdateAvailable(
            installedCode: installedCode,
            remoteCode: latest.code,
            remoteLabel: latest.label,
            asset: latest.asset,
          );
        case VersionRelation.same:
          return AppUpdateReinstall(
            installedCode: installedCode,
            remoteCode: latest.code,
            remoteLabel: latest.label,
            asset: latest.asset,
          );
        case VersionRelation.newer:
          return AppUpdateTipAhead(
            installedCode: installedCode,
            remoteCode: latest.code,
            remoteLabel: latest.label,
            asset: latest.asset,
          );
      }
    } catch (e) {
      return AppUpdateCheckFailed(e.toString());
    }
  }
}
