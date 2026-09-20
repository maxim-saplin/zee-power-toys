import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — deployment-time configuration.
// Publish checklist: docs/publish/0044-notes-for-maxim.md
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
/// Clone:  /Users/admin/src/ynavi-zee  (verified: `git ls-files '*.apk'`)
/// Branch: hud — the branch the HUD/minimap work lives on. (`speedcam` was a
///         stale feature branch, now out of scope; `main` lacks the P1 patch.)
/// Path:   modded_apks/zeekr_signed_v11.apk  (Zeekr-specific signed build)
///
/// KNOWN BROKEN — the published artifact cannot bind, and no committed APK
/// currently can. Verified on T2 (2026-07-31): `zeekr_signed_v11.apk` predates
/// the **P1 host-allowlist bypass** that was applied to the mod source on
/// Mar 11, so `NavigationCarAppService.c()` still returns the stock validator
/// instead of `ALLOW_ALL_HOSTS_VALIDATOR`. Binding therefore fails with
/// `CarApp.Val: Unrecognized host` → `onHandshakeCompleted FAILURE`, and the
/// HUD stays black. The blob is byte-identical on `hud` and `main`, so
/// switching branch alone changes nothing.
///
/// What works today is a local build from the `hud` branch —
/// `/Users/admin/src/ynavi-zee/builds/zeekr_signed.apk` — but `builds/` is
/// gitignored, so it is not downloadable.
///
/// TO FIX (requires action in the ynavi-zee repo, not here): commit a post-P1
/// build under `modded_apks/` on `hud` as a new version (e.g.
/// `zeekr_signed_v12.apk`, Git-LFS tracked), then bump [path] below.
/// Until then the in-app YNavi installer produces a non-working mod; install
/// manually with `uv run dev/ynavi_prep.py --apk <path>` instead.
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'modded_apks/zeekr_signed_v11.apk',
);

/// Modded Launcher APK — provides YNavi as default navigation app.
///
/// Repo:   https://github.com/maxim-saplin/zee_hud_2
/// Clone:  /Users/admin/src/zee_hud_2  (verified: `git ls-files '*.apk'`)
/// Branch: main — the APK is present here and **absent on `speedcam`**, which
///         this used to point at. Verified 2026-07-31 with `git cat-file -e`:
///         the path is missing on `speedcam` but resolves to blob 3a8dbd65 on
///         `main`, so the old value produced a 404 download.
/// Path:   zeekr_apk_mod_vendor/6.7.0/modded_apks/XCLauncher3-670-proxy-signed-v8.apk
///         (latest versioned signed build in the tree)
///
/// Untested end-to-end: the download URL is now correct, but installing the
/// modded Launcher has never been runtime-confirmed on T2 or the car.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zee_hud_2',
  branch: 'main',
  path: 'zeekr_apk_mod_vendor/6.7.0/modded_apks/XCLauncher3-670-proxy-signed-v8.apk',
);
