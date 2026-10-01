import 'dart:convert';

import 'package:http/http.dart' as http;

import 'install_targets.dart';
import 'installer.dart';

/// GitHub asset name for the machine-readable release manifest (0126).
const String kYnaviReleaseManifestAssetName = 'ynavi-release-manifest.json';

const String kYnaviReleaseRepo = 'maxim-saplin/ynavi-zee';

/// Variant ids from ynavi-zee `releases/lines.json`.
const String kYnaviVariantZeekrMargined = 'zeekr-padded';
const String kYnaviVariantZeekrOs7 = 'zeekr-os7';
const String kYnaviVariantZeekrV30 = 'zeekr-v30';

/// Network budget for Install-screen YNavi discovery (0126).
const Duration kYnaviReleaseDiscoveryTimeout = Duration(seconds: 20);

/// Parsed manifest (`schemaVersion` 1).
class YnaviReleaseManifest {
  const YnaviReleaseManifest({
    required this.channel,
    required this.lineId,
    required this.upstreamVersionName,
    required this.modBuild,
    required this.versionName,
    required this.versionCode,
    required this.tag,
    required this.assets,
  });

  final String channel;
  final String lineId;
  final String upstreamVersionName;
  final int modBuild;
  final String versionName;
  final int versionCode;
  final String tag;
  final List<YnaviManifestAssetEntry> assets;

  YnaviManifestAssetEntry? assetForVariant(String variantId) {
    for (final a in assets) {
      if (a.variant == variantId) return a;
    }
    return null;
  }
}

class YnaviManifestAssetEntry {
  const YnaviManifestAssetEntry({
    required this.variant,
    required this.filename,
    required this.sha256,
    required this.versionName,
    required this.versionCode,
  });

  final String variant;
  final String filename;
  final String sha256;
  final String versionName;
  final int versionCode;
}

/// Resolved latest release for one YNavi line (stable v27 or beta v30).
class YnaviResolvedRelease {
  const YnaviResolvedRelease({
    required this.manifest,
    required this.assetsByVariant,
  });

  final YnaviReleaseManifest manifest;

  /// Variant id → installable [GithubAsset] (directUrl when known).
  final Map<String, GithubAsset> assetsByVariant;

  int get versionCode => manifest.versionCode;
  String get versionLabel => manifest.versionName;
  String get tag => manifest.tag;
}

sealed class YnaviReleaseDiscoveryResult {
  const YnaviReleaseDiscoveryResult();
}

/// At least one channel resolved from GitHub; [stable] / [beta] may be null.
class YnaviReleaseDiscoveryOk extends YnaviReleaseDiscoveryResult {
  const YnaviReleaseDiscoveryOk({this.stable, this.beta});

  final YnaviResolvedRelease? stable;
  final YnaviResolvedRelease? beta;
}

class YnaviReleaseDiscoveryFailed extends YnaviReleaseDiscoveryResult {
  const YnaviReleaseDiscoveryFailed(this.message);
  final String message;
}

typedef YnaviReleaseDiscoverer = Future<YnaviReleaseDiscoveryResult> Function();

/// Parses manifest JSON. Returns null on malformed / unsupported schema.
YnaviReleaseManifest? parseYnaviReleaseManifest(Object? json) {
  if (json is! Map) return null;
  final map = Map<String, dynamic>.from(json);
  if (map['schemaVersion'] != 1) return null;

  final channel = map['channel'] as String?;
  final lineId = map['lineId'] as String?;
  final upstream = map['upstreamVersionName'] as String?;
  final modBuild = map['modBuild'];
  final versionName = map['versionName'] as String?;
  final versionCode = map['versionCode'];
  final tag = map['tag'] as String?;
  final rawAssets = map['assets'];
  if (channel == null ||
      lineId == null ||
      upstream == null ||
      modBuild is! int ||
      modBuild < 1 ||
      versionName == null ||
      versionCode is! int ||
      versionCode < 1 ||
      tag == null ||
      tag.isEmpty ||
      rawAssets is! List ||
      rawAssets.isEmpty) {
    return null;
  }

  final assets = <YnaviManifestAssetEntry>[];
  for (final item in rawAssets) {
    if (item is! Map) return null;
    final a = Map<String, dynamic>.from(item);
    final variant = a['variant'] as String?;
    final filename = a['filename'] as String?;
    final sha256 = a['sha256'] as String?;
    final aName = a['versionName'] as String?;
    final aCode = a['versionCode'];
    if (variant == null ||
        variant.isEmpty ||
        filename == null ||
        !filename.endsWith('.apk') ||
        sha256 == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        aName == null ||
        aCode is! int) {
      return null;
    }
    assets.add(
      YnaviManifestAssetEntry(
        variant: variant,
        filename: filename,
        sha256: sha256,
        versionName: aName,
        versionCode: aCode,
      ),
    );
  }

  return YnaviReleaseManifest(
    channel: channel,
    lineId: lineId,
    upstreamVersionName: upstream,
    modBuild: modBuild,
    versionName: versionName,
    versionCode: versionCode,
    tag: tag,
    assets: assets,
  );
}

/// Legacy / tag-only identity when no manifest asset exists (migration baselines).
class YnaviTagIdentity {
  const YnaviTagIdentity({
    required this.lineId,
    required this.upstreamVersionName,
    required this.modBuild,
    required this.versionCode,
    required this.versionName,
    required this.tag,
    required this.channel,
  });

  final String lineId;
  final String upstreamVersionName;
  final int modBuild;
  final int versionCode;
  final String versionName;
  final String tag;
  final String channel;
}

/// Parses `ynavi-zeekr-v27.0.2+3`, legacy `ynavi-zeekr-v27.0.2`, `ynavi-zeekr-v30`.
YnaviTagIdentity? parseYnaviReleaseTag(String tag) {
  final t = tag.trim();
  if (t == 'ynavi-zeekr-v30') {
    return YnaviTagIdentity(
      lineId: 'v30',
      upstreamVersionName: kYnaviV30UpstreamVersionName,
      modBuild: 0,
      versionCode: kYnaviV30ReleaseVersionCode,
      versionName: kYnaviV30UpstreamVersionName,
      tag: t,
      channel: 'beta',
    );
  }

  final m = RegExp(r'^ynavi-zeekr-v(\d+\.\d+\.\d+)(?:\+(\d+))?$').firstMatch(t);
  if (m == null) return null;

  final upstream = m.group(1)!;
  final modBuild = int.tryParse(m.group(2) ?? '') ?? 0;

  if (upstream == kYnaviUpstreamVersionName) {
    final code = kYnaviReleaseVersionCode + modBuild;
    final name = modBuild > 0 ? '$upstream+$modBuild' : upstream;
    return YnaviTagIdentity(
      lineId: 'v27',
      upstreamVersionName: upstream,
      modBuild: modBuild,
      versionCode: code,
      versionName: name,
      tag: t,
      channel: 'stable',
    );
  }
  if (upstream == kYnaviV30UpstreamVersionName) {
    final code = kYnaviV30ReleaseVersionCode + modBuild;
    final name = modBuild > 0 ? '$upstream+$modBuild' : upstream;
    return YnaviTagIdentity(
      lineId: 'v30',
      upstreamVersionName: upstream,
      modBuild: modBuild,
      versionCode: code,
      versionName: name,
      tag: t,
      channel: 'beta',
    );
  }
  return null;
}

GithubAsset githubAssetFromRelease({
  required String repo,
  required String tag,
  required String filename,
  required List<Map<String, dynamic>> releaseAssets,
}) {
  String? directUrl;
  for (final a in releaseAssets) {
    if (a['name'] == filename) {
      directUrl = a['browser_download_url'] as String?;
      break;
    }
  }
  return GithubAsset(
    repo: repo,
    branch: 'main',
    path: filename,
    releaseTag: tag,
    directUrl: directUrl?.isNotEmpty == true ? directUrl : null,
  );
}

YnaviResolvedRelease? resolvedFromManifest({
  required YnaviReleaseManifest manifest,
  required List<Map<String, dynamic>> releaseAssets,
  String repo = kYnaviReleaseRepo,
}) {
  final byVariant = <String, GithubAsset>{};
  for (final entry in manifest.assets) {
    final asset = githubAssetFromRelease(
      repo: repo,
      tag: manifest.tag,
      filename: entry.filename,
      releaseAssets: releaseAssets,
    );
    byVariant[entry.variant] = asset;
  }
  if (byVariant.isEmpty) return null;
  return YnaviResolvedRelease(manifest: manifest, assetsByVariant: byVariant);
}

/// Picks the better candidate by [versionCode] (0126 ordering).
T? pickNewerRelease<T>(T? current, T candidate, int Function(T) readCode) {
  if (current == null) return candidate;
  return readCode(candidate) > readCode(current) ? candidate : current;
}

bool _manifestMatchesStableV27(YnaviReleaseManifest m) =>
    m.lineId == 'v27' && m.channel == 'stable';

bool _manifestMatchesBetaV30(YnaviReleaseManifest m) =>
    m.lineId == 'v30' && m.channel == 'beta';

class YnaviReleaseDiscovery {
  YnaviReleaseDiscovery({
    http.Client? client,
    this.repo = kYnaviReleaseRepo,
    this.apiBase = 'https://api.github.com',
    this.timeout = kYnaviReleaseDiscoveryTimeout,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String repo;
  final String apiBase;
  final Duration timeout;

  Future<YnaviReleaseDiscoveryResult> discover() async {
    final uri = Uri.parse('$apiBase/repos/$repo/releases?per_page=100');
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
        return YnaviReleaseDiscoveryFailed('GitHub HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body);
      if (body is! List) {
        return const YnaviReleaseDiscoveryFailed('Unexpected releases payload');
      }

      YnaviResolvedRelease? bestStable;
      YnaviResolvedRelease? bestBeta;

      for (final item in body) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if (map['draft'] == true) continue;

        final tag = (map['tag_name'] as String?) ?? '';
        if (tag.isEmpty) continue;

        final rawAssets = map['assets'];
        final releaseAssets = rawAssets is List
            ? rawAssets
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        YnaviReleaseManifest? manifest;
        final manifestUrl = _manifestDownloadUrl(releaseAssets);
        if (manifestUrl != null) {
          manifest = await _fetchManifest(manifestUrl);
        }

        if (manifest != null) {
          final resolved = resolvedFromManifest(
            manifest: manifest,
            releaseAssets: releaseAssets,
            repo: repo,
          );
          if (resolved == null) continue;
          if (_manifestMatchesStableV27(manifest)) {
            bestStable = pickNewerRelease(
              bestStable,
              resolved,
              (r) => r.versionCode,
            );
          } else if (_manifestMatchesBetaV30(manifest)) {
            bestBeta = pickNewerRelease(
              bestBeta,
              resolved,
              (r) => r.versionCode,
            );
          }
          continue;
        }

        // Graceful fallback: legacy tag-only releases (no manifest asset).
        final identity = parseYnaviReleaseTag(tag);
        if (identity == null) continue;

        final synthetic = _syntheticManifest(identity, releaseAssets, tag);
        if (synthetic == null) continue;

        if (identity.lineId == 'v27' && identity.channel == 'stable') {
          bestStable = pickNewerRelease(
            bestStable,
            synthetic,
            (r) => r.versionCode,
          );
        } else if (identity.lineId == 'v30' && identity.channel == 'beta') {
          bestBeta = pickNewerRelease(
            bestBeta,
            synthetic,
            (r) => r.versionCode,
          );
        }
      }

      if (bestStable == null && bestBeta == null) {
        return const YnaviReleaseDiscoveryFailed('No YNavi releases resolved');
      }
      return YnaviReleaseDiscoveryOk(stable: bestStable, beta: bestBeta);
    } catch (e) {
      return YnaviReleaseDiscoveryFailed(e.toString());
    }
  }

  String? _manifestDownloadUrl(List<Map<String, dynamic>> releaseAssets) {
    for (final a in releaseAssets) {
      final name = a['name'] as String? ?? '';
      if (name == kYnaviReleaseManifestAssetName ||
          name.endsWith('ynavi-release-manifest.json')) {
        final url = a['browser_download_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  Future<YnaviReleaseManifest?> _fetchManifest(String url) async {
    try {
      final res = await _client.get(Uri.parse(url)).timeout(timeout);
      if (res.statusCode != 200) return null;
      return parseYnaviReleaseManifest(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  YnaviResolvedRelease? _syntheticManifest(
    YnaviTagIdentity identity,
    List<Map<String, dynamic>> releaseAssets,
    String tag,
  ) {
    final apkAssets = releaseAssets
        .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
        .toList();
    if (apkAssets.isEmpty) return null;

    final entries = <YnaviManifestAssetEntry>[];
    for (final a in apkAssets) {
      final filename = a['name'] as String? ?? '';
      if (filename.isEmpty) continue;
      final variant = _guessVariantFromFilename(filename, identity.lineId);
      if (variant == null) continue;
      entries.add(
        YnaviManifestAssetEntry(
          variant: variant,
          filename: filename,
          sha256: '0' * 64,
          versionName: identity.versionName,
          versionCode: identity.versionCode,
        ),
      );
    }
    if (entries.isEmpty) return null;

    final manifest = YnaviReleaseManifest(
      channel: identity.channel,
      lineId: identity.lineId,
      upstreamVersionName: identity.upstreamVersionName,
      modBuild: identity.modBuild,
      versionName: identity.versionName,
      versionCode: identity.versionCode,
      tag: tag,
      assets: entries,
    );
    return resolvedFromManifest(
      manifest: manifest,
      releaseAssets: releaseAssets,
      repo: repo,
    );
  }

  String? _guessVariantFromFilename(String filename, String lineId) {
    if (lineId == 'v27') {
      if (filename.contains('_margined')) return kYnaviVariantZeekrMargined;
      if (filename.contains('_os7')) return kYnaviVariantZeekrOs7;
      if (filename.startsWith('deepal_')) return 'deepal';
    }
    if (lineId == 'v30') {
      if (filename.contains('zeekr') && filename.contains('arm64')) {
        return kYnaviVariantZeekrV30;
      }
    }
    return null;
  }
}
