/// OTA-installer port.
/// Streams progress from download → install → done/failed.
abstract class Installer {
  Stream<InstallProgress> install(GithubAsset asset);
}

class GithubAsset {
  const GithubAsset({
    required this.repo,
    required this.tag,
    required this.assetName,
  });
  final String repo;
  final String tag;
  final String assetName;
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
