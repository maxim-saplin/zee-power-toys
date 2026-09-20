import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — deployment-time configuration.
// Publish checklist: docs/publish/0044-notes-for-maxim.md
//
// LFS raw CDN (public repos only anonymously):
//   https://media.githubusercontent.com/media/<repo>/<branch>/<path>
// Release assets:
//   https://github.com/<repo>/releases/download/<tag>/<filename>
// ---------------------------------------------------------------------------

/// YNavi mod — **DEFAULT** (margined / left letterbox 480dp). Zeekr panel layout.
///
/// Pending Maxim go: publish post-P1 build as LFS
/// `modded_apks/zeekr_signed_v12.apk` on `hud`. Until then live LFS is still
/// pre-P1 `v11` (bind broken). Local build: `ynavi-zee/builds/zeekr_signed.apk`
/// / HARDEN `zeekr_v12_margined`.
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'modded_apks/zeekr_signed_v12.apk',
);

/// YNavi mod — **OS7+** (left letterbox DISABLED, LEFT_DIP=0).
///
/// Pending: `modded_apks/zeekr_signed_v12_os7_nomargin.apk` on `hud`.
const GithubAsset kYnaviOs7Asset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'modded_apks/zeekr_signed_v12_os7_nomargin.apk',
);

/// Modded Launcher — staged for **zee-power-toys GitHub Release** (PDM default
/// while Maxim reviews; he can veto).
///
/// Local staged copy (gitignored): `artifacts/launcher/XCLauncher3-670-proxy-signed-v8.apk`
/// (copied from zee_hud_2). On go:
///   gh release create install-apks-v1 \\
///     artifacts/launcher/XCLauncher3-670-proxy-signed-v8.apk \\
///     --repo maxim-saplin/zee-power-toys
///
/// NOTE: `zee-power-toys` is **private** today — Release assets still need the
/// repo public (or auth) for anonymous Install. Same class of blocker as
/// zee_hud_2 LFS until visibility/host is fixed.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zee-power-toys',
  branch: 'main',
  path: 'XCLauncher3-670-proxy-signed-v8.apk',
  releaseTag: 'install-apks-v1',
);
