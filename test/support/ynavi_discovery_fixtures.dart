import 'package:zee_power_toys/services/install_targets.dart';
import 'package:zee_power_toys/services/installer.dart';
import 'package:zee_power_toys/services/ynavi_release_discovery.dart';

/// Compile-time migration baseline as a resolved discovery result (tests / offline).
YnaviReleaseDiscoveryOk baselineYnaviDiscoveryOk() {
  final stableManifest = YnaviReleaseManifest(
    channel: 'stable',
    lineId: 'v27',
    upstreamVersionName: kYnaviUpstreamVersionName,
    modBuild: 0,
    versionName: kYnaviUpstreamVersionName,
    versionCode: kYnaviReleaseVersionCode,
    tag: kYnaviReleaseTag,
    assets: [
      YnaviManifestAssetEntry(
        variant: kYnaviVariantZeekrMargined,
        filename: kYnaviAsset.path,
        sha256: '0' * 64,
        versionName: kYnaviUpstreamVersionName,
        versionCode: kYnaviReleaseVersionCode,
      ),
      YnaviManifestAssetEntry(
        variant: kYnaviVariantZeekrOs7,
        filename: kYnaviOs7Asset.path,
        sha256: '0' * 64,
        versionName: kYnaviUpstreamVersionName,
        versionCode: kYnaviReleaseVersionCode,
      ),
    ],
  );
  final betaManifest = YnaviReleaseManifest(
    channel: 'beta',
    lineId: 'v30',
    upstreamVersionName: kYnaviV30UpstreamVersionName,
    modBuild: 0,
    versionName: kYnaviV30UpstreamVersionName,
    versionCode: kYnaviV30ReleaseVersionCode,
    tag: kYnaviV30ReleaseTag,
    assets: [
      YnaviManifestAssetEntry(
        variant: kYnaviVariantZeekrV30,
        filename: kYnaviV30Asset.path,
        sha256: '0' * 64,
        versionName: kYnaviV30UpstreamVersionName,
        versionCode: kYnaviV30ReleaseVersionCode,
      ),
    ],
  );

  GithubAsset assetFrom(GithubAsset template, YnaviManifestAssetEntry entry) =>
      GithubAsset(
        repo: template.repo,
        branch: template.branch,
        path: entry.filename,
        releaseTag: template.releaseTag,
      );

  return YnaviReleaseDiscoveryOk(
    stable: YnaviResolvedRelease(
      manifest: stableManifest,
      assetsByVariant: {
        kYnaviVariantZeekrMargined:
            assetFrom(kYnaviAsset, stableManifest.assets[0]),
        kYnaviVariantZeekrOs7:
            assetFrom(kYnaviOs7Asset, stableManifest.assets[1]),
      },
    ),
    beta: YnaviResolvedRelease(
      manifest: betaManifest,
      assetsByVariant: {
        kYnaviVariantZeekrV30: assetFrom(kYnaviV30Asset, betaManifest.assets[0]),
      },
    ),
  );
}

Future<YnaviReleaseDiscoveryResult> baselineYnaviDiscoverer() async =>
    baselineYnaviDiscoveryOk();
