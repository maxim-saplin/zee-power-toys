import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zee_power_toys/services/app_self_update.dart';
import 'package:zee_power_toys/services/installer.dart';

void main() {
  group('parseVersionCode', () {
    test('plus build', () {
      expect(parseVersionCode('1.0.0+3'), 3);
      expect(parseVersionCode('v1.0.0+12'), 12);
    });

    test('semver only → 0', () {
      expect(parseVersionCode('1.0.0'), 0);
      expect(parseVersionCode('v1.2.3'), 0);
    });

    test('garbage', () {
      expect(parseVersionCode('nightly'), isNull);
    });
  });

  group('AppSelfUpdate.check', () {
    test('update available picks highest code', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/repos/maxim-saplin/zee-power-toys/releases');
        return http.Response(
          jsonEncode([
            {
              'tag_name': '1.0.0+2',
              'name': 'old',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'zee-power-toys.apk',
                  'browser_download_url':
                      'https://github.com/x/y/releases/download/1.0.0+2/zee-power-toys.apk',
                },
              ],
            },
            {
              'tag_name': '1.0.0+5',
              'name': 'new',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'app-release.apk',
                  'browser_download_url':
                      'https://github.com/x/y/releases/download/1.0.0+5/app-release.apk',
                },
              ],
            },
            {
              'tag_name': '1.0.0+9',
              'draft': true,
              'prerelease': false,
              'assets': [
                {
                  'name': 'zee-power-toys.apk',
                  'browser_download_url': 'https://example.com/draft.apk',
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final check = await AppSelfUpdate(
        client: client,
        installedCode: 3,
      ).check();
      expect(check, isA<AppUpdateAvailable>());
      final avail = check as AppUpdateAvailable;
      expect(avail.remoteCode, 5);
      expect(avail.asset.path, 'app-release.apk');
      expect(avail.asset.directUrl, contains('1.0.0+5'));
    });

    test('same build → reinstall with asset', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': '1.0.0+3',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'zee-power-toys.apk',
                  'browser_download_url': 'https://example.com/a.apk',
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final check = await AppSelfUpdate(
        client: client,
        installedCode: 3,
      ).check();
      expect(check, isA<AppUpdateReinstall>());
      final same = check as AppUpdateReinstall;
      expect(same.remoteCode, 3);
      expect(same.asset.directUrl, 'https://example.com/a.apk');
    });

    test('tip ahead of published → tipAhead with Release asset', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': '1.0.0+3',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'zee-power-toys.apk',
                  'browser_download_url': 'https://example.com/a.apk',
                },
              ],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final check = await AppSelfUpdate(
        client: client,
        installedCode: 9,
      ).check();
      expect(check, isA<AppUpdateTipAhead>());
      final tip = check as AppUpdateTipAhead;
      expect(tip.remoteCode, 3);
      expect(tip.installedCode, 9);
      expect(tip.asset.path, 'zee-power-toys.apk');
    });

    test('http failure', () async {
      final client = MockClient((request) async {
        return http.Response('nope', 403);
      });
      final check = await AppSelfUpdate(client: client, installedCode: 1).check();
      expect(check, isA<AppUpdateCheckFailed>());
    });
  });

  test('GithubAsset directUrl wins', () {
    const a = GithubAsset(
      repo: 'o/r',
      branch: 'main',
      path: 'x.apk',
      releaseTag: 'ignored',
      directUrl: 'https://cdn.example/x.apk',
    );
    expect(a.downloadUrl, 'https://cdn.example/x.apk');
  });
}
