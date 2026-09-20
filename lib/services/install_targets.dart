import 'installer.dart';

// ---------------------------------------------------------------------------
// Install targets — GitHub **Release** assets on source repos only.
// No APKs in zee-power-toys git (Maxim 0044).
//
// Draft Releases use untagged-* download paths until published; anonymous
// HEAD on drafts is 404. After Maxim undrafts/publishes, tag URLs resolve.
// Draft exercise URLs — see docs/publish/0044-notes-for-maxim.md.
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

/// Launcher — zee_hud_2 Release only.
const GithubAsset kLauncherAsset = GithubAsset(
  repo: 'maxim-saplin/zee_hud_2',
  branch: 'main',
  path: 'XCLauncher3-670-proxy-signed-v8.apk',
  releaseTag: 'launcher-v8',
);
