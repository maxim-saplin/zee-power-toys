import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/install_targets.dart';

void main() {
  test('YNavi Release names use upstream 27.0.2, not internal v12', () {
    expect(kYnaviUpstreamVersionName, '27.0.2');
    expect(kYnaviUpstreamLabel, 'v27.0.2');
    expect(kYnaviUpstreamVersionBuild, '27.0.2+738798690');
    expect(kYnaviReleaseTag, 'ynavi-zeekr-v27.0.2');
    expect(kYnaviReleaseTag, isNot(contains('v12')));

    expect(kYnaviAsset.releaseTag, kYnaviReleaseTag);
    expect(kYnaviAsset.path, 'zeekr_v27.0.2_margined.apk');
    expect(kYnaviOs7Asset.releaseTag, kYnaviReleaseTag);
    expect(kYnaviOs7Asset.path, 'zeekr_v27.0.2_os7_nomargin.apk');
    expect(kYnaviAsset.path, isNot(contains('v12')));
    expect(kYnaviOs7Asset.path, isNot(contains('v12')));
  });
}
