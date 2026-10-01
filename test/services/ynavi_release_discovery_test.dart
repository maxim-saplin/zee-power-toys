import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zee_power_toys/services/install_targets.dart';
import 'package:zee_power_toys/services/ynavi_release_discovery.dart';

void main() {
  group('parseYnaviReleaseTag', () {
    test('numbered v27 tag', () {
      final id = parseYnaviReleaseTag('ynavi-zeekr-v27.0.2+3');
      expect(id, isNotNull);
      expect(id!.versionCode, kYnaviReleaseVersionCode + 3);
      expect(id.versionName, '27.0.2+3');
      expect(id.lineId, 'v27');
    });

    test('legacy unnumbered v27', () {
      final id = parseYnaviReleaseTag('ynavi-zeekr-v27.0.2');
      expect(id!.versionCode, kYnaviReleaseVersionCode);
      expect(id.modBuild, 0);
    });

    test('legacy v30 shorthand tag', () {
      final id = parseYnaviReleaseTag('ynavi-zeekr-v30');
      expect(id!.lineId, 'v30');
      expect(id.versionCode, kYnaviV30ReleaseVersionCode);
    });
  });

  group('parseYnaviReleaseManifest', () {
    test('valid manifest', () {
      final m = parseYnaviReleaseManifest({
        'schemaVersion': 1,
        'channel': 'stable',
        'lineId': 'v27',
        'upstreamVersionName': '27.0.2',
        'modBuild': 2,
        'versionName': '27.0.2+2',
        'versionCode': 738798692,
        'tag': 'ynavi-zeekr-v27.0.2+2',
        'repo': 'maxim-saplin/ynavi-zee',
        'gitCommit': 'abc1234',
        'assets': [
          {
            'variant': 'zeekr-padded',
            'filename': 'zeekr_v27.0.2+2_margined.apk',
            'sha256': 'a' * 64,
            'versionName': '27.0.2+2',
            'versionCode': 738798692,
          },
        ],
      });
      expect(m, isNotNull);
      expect(m!.assetForVariant('zeekr-padded')!.filename,
          'zeekr_v27.0.2+2_margined.apk');
    });

    test('rejects malformed manifest', () {
      expect(parseYnaviReleaseManifest({'schemaVersion': 2}), isNull);
      expect(parseYnaviReleaseManifest({'schemaVersion': 1}), isNull);
    });
  });

  group('YnaviReleaseDiscovery.discover', () {
    Map<String, dynamic> release({
      required String tag,
      required List<Map<String, dynamic>> assets,
      bool prerelease = false,
      Map<String, dynamic>? manifest,
    }) {
      final listAssets = <Map<String, dynamic>>[
        ...assets,
        if (manifest != null)
          {
            'name': kYnaviReleaseManifestAssetName,
            'browser_download_url': 'https://example.com/manifest/$tag.json',
          },
      ];
      return {
        'tag_name': tag,
        'draft': false,
        'prerelease': prerelease,
        'assets': listAssets,
      };
    }

    test('prefers manifest and highest mod build on stable', () async {
      final manifests = <String, Map<String, dynamic>>{
        'ynavi-zeekr-v27.0.2+1': {
          'schemaVersion': 1,
          'channel': 'stable',
          'lineId': 'v27',
          'upstreamVersionName': '27.0.2',
          'modBuild': 1,
          'versionName': '27.0.2+1',
          'versionCode': kYnaviReleaseVersionCode + 1,
          'tag': 'ynavi-zeekr-v27.0.2+1',
          'repo': kYnaviReleaseRepo,
          'gitCommit': 'abc1234',
          'assets': [
            {
              'variant': kYnaviVariantZeekrMargined,
              'filename': 'zeekr_v27.0.2+1_margined.apk',
              'sha256': 'b' * 64,
              'versionName': '27.0.2+1',
              'versionCode': kYnaviReleaseVersionCode + 1,
            },
          ],
        },
        'ynavi-zeekr-v27.0.2+2': {
          'schemaVersion': 1,
          'channel': 'stable',
          'lineId': 'v27',
          'upstreamVersionName': '27.0.2',
          'modBuild': 2,
          'versionName': '27.0.2+2',
          'versionCode': kYnaviReleaseVersionCode + 2,
          'tag': 'ynavi-zeekr-v27.0.2+2',
          'repo': kYnaviReleaseRepo,
          'gitCommit': 'abc1234',
          'assets': [
            {
              'variant': kYnaviVariantZeekrMargined,
              'filename': 'zeekr_v27.0.2+2_margined.apk',
              'sha256': 'c' * 64,
              'versionName': '27.0.2+2',
              'versionCode': kYnaviReleaseVersionCode + 2,
            },
          ],
        },
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/releases')) {
          return http.Response(
            jsonEncode([
              release(
                tag: 'ynavi-zeekr-v27.0.2+1',
                assets: [
                  {
                    'name': 'zeekr_v27.0.2+1_margined.apk',
                    'browser_download_url': 'https://example.com/1.apk',
                  },
                ],
                manifest: manifests['ynavi-zeekr-v27.0.2+1'],
              ),
              release(
                tag: 'ynavi-zeekr-v27.0.2+2',
                assets: [
                  {
                    'name': 'zeekr_v27.0.2+2_margined.apk',
                    'browser_download_url': 'https://example.com/2.apk',
                  },
                ],
                manifest: manifests['ynavi-zeekr-v27.0.2+2'],
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        for (final e in manifests.entries) {
          if (request.url.path.endsWith('${e.key}.json')) {
            return http.Response(jsonEncode(e.value), 200);
          }
        }
        return http.Response('missing', 404);
      });

      final result = await YnaviReleaseDiscovery(client: client).discover();
      expect(result, isA<YnaviReleaseDiscoveryOk>());
      final ok = result as YnaviReleaseDiscoveryOk;
      expect(ok.stable!.versionCode, kYnaviReleaseVersionCode + 2);
      expect(
        ok.stable!.assetsByVariant[kYnaviVariantZeekrMargined]!.path,
        'zeekr_v27.0.2+2_margined.apk',
      );
    });

    test('resolves beta v30 channel', () async {
      const tag = 'ynavi-zeekr-v30.8.1+1';
      final manifest = {
        'schemaVersion': 1,
        'channel': 'beta',
        'lineId': 'v30',
        'upstreamVersionName': '30.8.1',
        'modBuild': 1,
        'versionName': '30.8.1+1',
        'versionCode': kYnaviV30ReleaseVersionCode + 1,
        'tag': tag,
        'repo': kYnaviReleaseRepo,
        'gitCommit': 'abc1234',
        'assets': [
          {
            'variant': kYnaviVariantZeekrV30,
            'filename': 'ynavi_30.8.1+1_zeekr_arm64_signed.apk',
            'sha256': 'd' * 64,
            'versionName': '30.8.1+1',
            'versionCode': kYnaviV30ReleaseVersionCode + 1,
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/releases')) {
          return http.Response(
            jsonEncode([
              release(
                tag: tag,
                prerelease: true,
                assets: [
                  {
                    'name': 'ynavi_30.8.1+1_zeekr_arm64_signed.apk',
                    'browser_download_url': 'https://example.com/v30.apk',
                  },
                ],
                manifest: manifest,
              ),
            ]),
            200,
          );
        }
        return http.Response(jsonEncode(manifest), 200);
      });

      final result = await YnaviReleaseDiscovery(client: client).discover();
      final ok = result as YnaviReleaseDiscoveryOk;
      expect(ok.beta!.versionCode, kYnaviV30ReleaseVersionCode + 1);
    });

    test('http failure', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final result = await YnaviReleaseDiscovery(client: client).discover();
      expect(result, isA<YnaviReleaseDiscoveryFailed>());
    });

    test('legacy tag-only release without manifest', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'ynavi-zeekr-v27.0.2',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'zeekr_v27.0.2_margined.apk',
                  'browser_download_url': 'https://example.com/legacy.apk',
                },
              ],
            },
          ]),
          200,
        );
      });
      final result = await YnaviReleaseDiscovery(client: client).discover();
      expect(result, isA<YnaviReleaseDiscoveryOk>());
      final ok = result as YnaviReleaseDiscoveryOk;
      expect(ok.stable!.versionCode, kYnaviReleaseVersionCode);
    });
  });
}
