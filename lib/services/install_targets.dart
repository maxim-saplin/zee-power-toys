import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — deployment-time configuration.
// Publish checklist: docs/publish/0044-notes-for-maxim.md
//
// Maxim 0044: APKs stay in **source repos** only. Install uses GitHub
// **Release** asset URLs (prep-branch workflows). No APK copies into
// zee-power-toys.
//
// Release: https://github.com/<repo>/releases/download/<tag>/<filename>
// LFS media (legacy / until Release exists): media.githubusercontent.com/...
// ---------------------------------------------------------------------------

/// YNavi — **DEFAULT** margined (left letterbox 480dp).
/// Source repo: maxim-saplin/ynavi-zee. Pending Release asset after Maxim go.
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_signed_v12.apk',
  releaseTag: 'ynavi-zeekr-v12',
);

/// YNavi — **OS7+** left letterbox DISABLED.
const GithubAsset kYnaviOs7Asset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_signed_v12_os7_nomargin.apk',
  releaseTag: 'ynavi-zeekr-v12',
);

/// Modded Launcher — source repo maxim-saplin/zee_hud_2 only.
/// Private LFS CDN 404 → fix via **public Release** on zee_hud_2 (not by
/// relocating the APK into zee-power-toys).
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zee_hud_2',
  branch: 'main',
  path: 'XCLauncher3-670-proxy-signed-v8.apk',
  releaseTag: 'launcher-v8',
);
