/// OTA-installer port.
/// Streams progress from download → install → done/failed.
abstract class Installer {
  Stream<InstallProgress> install(GithubAsset asset);
}

/// A GitHub-hosted APK — either Git-LFS raw media or a Release asset.
///
/// LFS (default when [releaseTag] is null):
///   `https://media.githubusercontent.com/media/<repo>/<branch>/<path>`
///
/// Release (when [releaseTag] is set):
///   `https://github.com/<repo>/releases/download/<tag>/<path>`
/// where [path] is the asset filename only (no directories).
///
/// Anonymous download requires a **public** repo (or auth). Private repos
/// 404 for sideload users — see docs/publish/0044-notes-for-maxim.md.
class GithubAsset {
  const GithubAsset({
    required this.repo,
    required this.branch,
    required this.path,
    this.releaseTag,
  });

  /// GitHub repository as "owner/repo-name" (no scheme, no .git).
  final String repo;

  /// Git branch (or tag/commit) where the LFS-tracked APK lives.
  /// Ignored for Release downloads when [releaseTag] is set (kept for docs).
  final String branch;

  /// LFS: path within the repo. Release: asset **filename** only.
  final String path;

  /// When non-null, [downloadUrl] uses GitHub Releases instead of LFS media.
  final String? releaseTag;

  /// Resolved download URL (LFS media or Release asset).
  String get downloadUrl {
    final tag = releaseTag;
    if (tag != null) {
      return 'https://github.com/$repo/releases/download/$tag/$path';
    }
    return 'https://media.githubusercontent.com/media/$repo/$branch/$path';
  }
}

class InstallProgress {
  const InstallProgress({
    required this.phase,
    required this.fraction,
    this.message,
  });

  final InstallPhase phase;
  final double fraction; // 0.0–1.0
  final String? message;
}

enum InstallPhase { downloading, installing, done, failed }
