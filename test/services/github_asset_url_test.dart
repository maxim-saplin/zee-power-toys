import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/installer.dart';

void main() {
  test('LFS media URL', () {
    const a = GithubAsset(repo: 'o/r', branch: 'hud', path: 'modded_apks/x.apk');
    expect(
      a.downloadUrl,
      'https://media.githubusercontent.com/media/o/r/hud/modded_apks/x.apk',
    );
  });

  test('Release asset URL', () {
    const a = GithubAsset(
      repo: 'o/r',
      branch: 'main',
      path: 'app.apk',
      releaseTag: 'install-apks-v1',
    );
    expect(
      a.downloadUrl,
      'https://github.com/o/r/releases/download/install-apks-v1/app.apk',
    );
  });
}
