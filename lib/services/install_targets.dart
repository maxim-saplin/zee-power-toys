import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — deployment-time configuration.
//
// Replace the placeholder values below with the real GitHub release
// coordinates when the actual releases are published.
//
// Format:
//   repo      — "owner/repo-name"  (no https://, no .git)
//   tag       — the release tag string, e.g. "v1.2.0"
//   assetName — the exact filename of the APK asset on that release
//
// The download URL is resolved by NativeInstaller to:
//   https://github.com/<repo>/releases/download/<tag>/<assetName>
// ---------------------------------------------------------------------------

// TODO: real release coordinates — replace with actual repo/tag/asset values.

/// Modded Launcher APK — provides YNavi as default navigation app.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'zeepowertoys/modded-launcher',        // TODO: real repo
  tag: 'v1.0.0',                                // TODO: real tag
  assetName: 'modded-launcher-release.apk',    // TODO: real asset name
);

/// YNavi mod APK — adds HUD support and minimap broadcast to Yandex.Navi.
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'zeepowertoys/ynavi-mod',              // TODO: real repo
  tag: 'v1.0.0',                               // TODO: real tag
  assetName: 'ynavi-mod-release.apk',          // TODO: real asset name
);
