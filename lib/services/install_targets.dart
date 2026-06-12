import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — deployment-time configuration.
//
// Both APKs are tracked as Git-LFS objects in their respective repos.
// The download URL resolves to the LFS raw-content CDN:
//   https://media.githubusercontent.com/media/<repo>/<branch>/<path>
//
// To update to a newer artifact:
//   1. Bump the [path] (and/or [branch]) to the new versioned filename.
//   2. Verify the file is git-tracked in the clone:
//        git -C /path/to/clone ls-files '*.apk'
//   3. Update this file and commit in the same Block.
// ---------------------------------------------------------------------------

/// YNavi mod APK — adds HUD support and minimap broadcast to Yandex.Navi.
///
/// Repo:   https://github.com/maxim-saplin/ynavi-zee
/// Clone:  /home/user/src/ynavi-zee  (verified: `git ls-files '*.apk'`)
/// Branch: speedcam
/// Path:   modded_apks/zeekr_signed_v11.apk  (Zeekr-specific signed build)
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'speedcam',
  path: 'modded_apks/zeekr_signed_v11.apk',
);

/// Modded Launcher APK — provides YNavi as default navigation app.
///
/// Repo:   https://github.com/maxim-saplin/zee_hud_2
/// Clone:  /home/user/src/zee_hud_2  (verified: `git ls-files '*.apk'`)
/// Branch: speedcam
/// Path:   zeekr_apk_mod_vendor/6.7.0/modded_apks/XCLauncher3-670-proxy-signed-v8.apk
///         (latest versioned signed build in the tree)
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zee_hud_2',
  branch: 'speedcam',
  path: 'zeekr_apk_mod_vendor/6.7.0/modded_apks/XCLauncher3-670-proxy-signed-v8.apk',
);
