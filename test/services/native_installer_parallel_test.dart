import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/adapters/native_installer.dart';
import 'package:zee_power_toys/services/install_self_update_url.dart';
import 'package:zee_power_toys/services/installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('zee/installer');
  const events = EventChannel('zee/installer/events');

  late NativeInstaller installer;
  late List<String> startedUrls;
  MockStreamHandlerEventSink? sink;
  var listenCount = 0;
  var cancelCount = 0;

  setUp(() {
    startedUrls = <String>[];
    listenCount = 0;
    cancelCount = 0;
    sink = null;
    installer = NativeInstaller(methodChannel: method, eventChannel: events);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, (call) async {
      if (call.method == 'start') {
        final url = (call.arguments as Map)['url'] as String;
        startedUrls.add(url);
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          listenCount++;
          // 0084: shared sub must not pass a per-install url in listen args.
          expect(arguments, isNull);
          sink = events;
        },
        onCancel: (Object? arguments) {
          cancelCount++;
          sink = null;
        },
      ),
    );
  });

  tearDown(() {
    installer.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(events, null);
  });

  GithubAsset asset(String file) => GithubAsset(
        repo: 'maxim-saplin/demo',
        branch: 'main',
        path: file,
        directUrl: 'https://example.test/$file',
      );

  test('parallel Update + YNavi keep one EventChannel listen and fan out by url',
      () async {
    final toysUrl = asset('zee-power-toys.apk').downloadUrl;
    final ynaviUrl = asset('zeekr_v27.0.2_margined.apk').downloadUrl;

    final toysEvents = <InstallProgress>[];
    final ynaviEvents = <InstallProgress>[];

    final toysDone = Completer<void>();
    final ynaviDone = Completer<void>();

    installer.install(asset('zee-power-toys.apk')).listen(
      toysEvents.add,
      onDone: toysDone.complete,
    );
    installer.install(asset('zeekr_v27.0.2_margined.apk')).listen(
      ynaviEvents.add,
      onDone: ynaviDone.complete,
    );

    await Future<void>.delayed(Duration.zero);

    expect(startedUrls, [toysUrl, ynaviUrl]);
    expect(listenCount, 1, reason: 'one shared EventChannel subscription');
    expect(installer.activeListenerCount, 2);
    expect(sink, isNotNull);

    sink!.success(<String, Object?>{
      'url': toysUrl,
      'phase': 'downloading',
      'fraction': 0.3,
    });
    sink!.success(<String, Object?>{
      'url': ynaviUrl,
      'phase': 'downloading',
      'fraction': 0.7,
    });
    sink!.success(<String, Object?>{
      'url': ynaviUrl,
      'phase': 'done',
      'fraction': 1.0,
    });
    sink!.success(<String, Object?>{
      'url': toysUrl,
      'phase': 'done',
      'fraction': 1.0,
    });

    await Future.wait<void>([toysDone.future, ynaviDone.future]);

    expect(toysEvents.map((e) => e.fraction), [0.3, 1.0]);
    expect(toysEvents.last.phase, InstallPhase.done);
    expect(ynaviEvents.map((e) => e.fraction), [0.7, 1.0]);
    expect(ynaviEvents.last.phase, InstallPhase.done);
    // Second job finishing tears the shared sub once — not per start.
    expect(cancelCount, 1);
    expect(installer.hasSharedSubscription, isFalse);
  });

  test('second install does not abort the first stream', () async {
    final a = asset('a.apk');
    final b = asset('b.apk');
    final aEvents = <InstallProgress>[];
    var aDone = false;

    installer.install(a).listen(aEvents.add, onDone: () => aDone = true);
    await Future<void>.delayed(Duration.zero);
    installer.install(b).listen((_) {});
    await Future<void>.delayed(Duration.zero);

    expect(aDone, isFalse);
    sink!.success(<String, Object?>{
      'url': a.downloadUrl,
      'phase': 'installing',
      'fraction': 0.8,
    });
    await Future<void>.delayed(Duration.zero);
    expect(aDone, isFalse);
    expect(aEvents.single.phase, InstallPhase.installing);

    sink!.success(<String, Object?>{
      'url': a.downloadUrl,
      'phase': 'done',
      'fraction': 1.0,
    });
    await Future<void>.delayed(Duration.zero);
    expect(aDone, isTrue);
  });

  test('isSelfUpdateUrl matches Kotlin companion-defer predicate', () {
    expect(
      isSelfUpdateUrl(
        'https://github.com/maxim-saplin/zee-power-toys/releases/download/v1/zee-power-toys.apk',
      ),
      isTrue,
    );
    expect(
      isSelfUpdateUrl(
        'https://github.com/maxim-saplin/zee-power-toys/releases/download/v1/app-release.apk',
      ),
      isTrue,
    );
    expect(
      isSelfUpdateUrl(
        'https://github.com/maxim-saplin/ynavi-zee/releases/download/t/zeekr_v27.0.2_margined.apk',
      ),
      isFalse,
    );
  });
}
