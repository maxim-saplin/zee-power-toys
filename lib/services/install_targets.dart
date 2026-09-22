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
