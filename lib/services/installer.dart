/// OTA-installer port.
/// Streams progress from download → install → done/failed.
abstract class Installer {
  Stream<InstallProgress> install(GithubAsset asset);
}

/// A GitHub-hosted APK asset stored in a Git-LFS-tracked repo.
///
/// The download URL is resolved to:
///   `https://media.githubusercontent.com/media/<repo>/<branch>/<path>`
/// which serves the raw LFS bytes directly (follows redirects transparently).
///
/// To update an artifact: bump [branch] (or [path]) to the new version in
/// `lib/services/install_targets.dart`.
class GithubAsset {
  const GithubAsset({
    required this.repo,
    required this.branch,
    required this.path,
  });

  /// GitHub repository as "owner/repo-name" (no scheme, no .git).
  final String repo;

  /// Git branch (or tag/commit) where the LFS-tracked APK lives.
  final String branch;

  /// File path within the repo (relative to the root), e.g.
  /// "modded_apks/zeekr_signed_v11.apk".
  final String path;

  /// Resolved LFS raw-content download URL.
  String get downloadUrl =>
      'https://media.githubusercontent.com/media/$repo/$branch/$path';
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
