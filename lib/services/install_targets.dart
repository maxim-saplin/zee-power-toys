import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — GitHub **Release** assets on publish repos only.
// Trio: zee-power-toys | ynavi-zee | zeekr_apk_mod
// zee_hud_2 is NOT in publishing scope.
// ---------------------------------------------------------------------------

/// Upstream Yandex Navi product bar (`apktool.yml` versionName).
/// Not the internal mod counter formerly baked into `v12` Release names.
const String kYnaviUpstreamVersionName = '27.0.2';

/// Upstream versionCode (apktool). Paired with [kYnaviUpstreamVersionName]
/// as Flutter-style `version+build`.
const String kYnaviUpstreamVersionCode = '738798690';

/// Honest Release / UI short label: upstream versionName with `v` prefix.
const String kYnaviUpstreamLabel = 'v$kYnaviUpstreamVersionName';

/// Flutter-style product label (`About` pattern): versionName+versionCode.
const String kYnaviUpstreamVersionBuild =
    '$kYnaviUpstreamVersionName+$kYnaviUpstreamVersionCode';


/// Release pin: upstream versionCode for companion Update/Reinstall compare (0103).
const int kYnaviReleaseVersionCode = 738798690;

/// Launcher Release pin (apktool versionCode for launcher-670 asset). Tag
/// `launcher-670` is the GH label; numeric compare uses this code.
const int kLauncherReleaseVersionCode = 305019;

/// Launcher product versionName for status labels (apktool).
const String kLauncherReleaseVersionName = '3.0.5019';


/// Release tag for all Deepal + Zeekr YNavi variants (0087).
const String kYnaviReleaseTag = 'ynavi-zeekr-v$kYnaviUpstreamVersionName';

/// YNavi — DEFAULT margined (left=480).
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_v${kYnaviUpstreamVersionName}_margined.apk',
  releaseTag: kYnaviReleaseTag,
);

/// YNavi — OS7+ no left margin.
const GithubAsset kYnaviOs7Asset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_v${kYnaviUpstreamVersionName}_os7_nomargin.apk',
  releaseTag: kYnaviReleaseTag,
);

/// YNavi v30 stretch — **beta / non-default** (0122 Zee parity tip).
/// Same package as v27; Install UI keeps v27 as the day-to-day default.
const String kYnaviV30UpstreamVersionName = '30.8.1';
const String kYnaviV30UpstreamVersionCode = '739652660';
const String kYnaviV30UpstreamVersionBuild =
    '$kYnaviV30UpstreamVersionName+$kYnaviV30UpstreamVersionCode';
const int kYnaviV30ReleaseVersionCode = 739652660;
const String kYnaviV30ReleaseTag = 'ynavi-zeekr-v30';

/// YNavi v30 Zee arm64 — Release `ynavi-zeekr-v30` (pre-release; beta Install card).
/// Tip `45fada46` / asset sha256 `a000a77f158fcccb87e0c12c1001b0f93f99366341ba9be2fc11daf8509b0e8e`.
const GithubAsset kYnaviV30Asset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'main',
  path: 'ynavi_30.8.1_zeekr_arm64_signed.apk',
  releaseTag: kYnaviV30ReleaseTag,
);

/// Zeekr Launcher mod (Yandex Navi as default) — **zeekr_apk_mod** only.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zeekr_apk_mod',
  branch: 'main',
  path: 'XCLauncher3-670-yandex-signed.apk',
  releaseTag: 'launcher-670',
);


/// Self-update (0069) — public Releases on this app's own repo.
const String kSelfUpdateRepo = 'maxim-saplin/zee-power-toys';

/// Preferred APK asset filenames on a Release (first match wins).
const List<String> kSelfUpdateAssetNames = <String>[
  'zee-power-toys.apk',
  'app-release.apk',
];
