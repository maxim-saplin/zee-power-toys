import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — GitHub **Release** assets on publish repos only.
// Trio: zee-power-toys | ynavi-zee | zeekr_apk_mod
// zee_hud_2 is NOT in publishing scope.
// ---------------------------------------------------------------------------

/// YNavi — DEFAULT margined (left=480).
const GithubAsset kYnaviAsset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_v12_margined.apk',
  releaseTag: 'ynavi-zeekr-v12',
);

/// YNavi — OS7+ no left margin.
const GithubAsset kYnaviOs7Asset = GithubAsset(
  repo: 'maxim-saplin/ynavi-zee',
  branch: 'hud',
  path: 'zeekr_v12_os7_nomargin.apk',
  releaseTag: 'ynavi-zeekr-v12',
);

/// Zeekr Launcher mod (Yandex Navi as default) — **zeekr_apk_mod** only.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zeekr_apk_mod',
  branch: 'main',
  path: 'XCLauncher3-670-yandex-signed.apk',
  releaseTag: 'launcher-670',
);
