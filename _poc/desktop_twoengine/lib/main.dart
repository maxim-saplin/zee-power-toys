// =============================================================================
// THROWAWAY PoC — desktop TWO-ENGINE topology for zee-power-toys ("T1 Desktop").
//
// Goal: prove the *faithful* Android-mirroring topology on Flutter 3.44.1 Linux
// desktop — TWO top-level OS windows, EACH backed by its OWN Flutter engine +
// isolate (a "PRIMARY/DHU" window and a "HUD" window), reachable by ONE Dart VM
// service, syncing ONLY through a native-mediated channel (the desktop "Hub"),
// never through shared Dart memory. This mirrors Android's FlutterEngineGroup
// (two isolates, native source-of-truth) per ADRs 0003/0004/0005.
//
// Mechanism: desktop_multi_window 0.3.0. On Linux it creates each window as a
// new fl_view_new()/FlEngine inside the SAME GtkApplication / SAME process,
// re-running this same main() with entrypoint args:
//     ["multi_window", "<uuid windowId>", "<userArgs>"]
//
// Probes (mirror _poc/multidisplay_poc + ADR 0004's ext.zee.* pattern):
//   counter            : per-isolate "shared-looking" state. MUST DIVERGE.
//   ext.zee.whoami     : {surface, isolate: identityHashCode, counter,
//                         configFromMain, pid, window}              (read)
//   ext.zee.bump       : increments THIS isolate's counter          (write)
//   ext.zee.pushConfig : PRIMARY pushes its counter to the HUD over the Hub
//                        channel (models the host-mediated config push)
//   configFromMain     : HUD value updated ONLY via the Hub channel (sync proof)
// =============================================================================

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show pid;
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Per-isolate "shared-looking" counter. In a single-isolate world every
/// surface would read the same value for free; with two engines each isolate
/// owns its OWN copy, so values diverge unless explicitly synced via the Hub.
final ValueNotifier<int> counter = ValueNotifier<int>(0);

/// HUD-only: the last value pushed from the PRIMARY window over the Hub channel.
/// Updated ONLY by the native-mediated channel — never by shared Dart heap.
final ValueNotifier<int> configFromMain = ValueNotifier<int>(-1);

String _surface = 'unknown';
String _windowTag = '(main)';

/// RepaintBoundary key for the VM-service screenshot probe (ext.zee.shot). Each
/// isolate builds exactly one of the two screens, so a single key is safe.
final GlobalKey _shotKey = GlobalKey();

/// The desktop "Hub": a native-mediated cross-engine channel. The HUD registers
/// the single handler (unidirectional); the PRIMARY invokes it. Routing happens
/// in the native ChannelRegistry (in-process), NOT via a shared Dart heap.
const String kHubChannel = 'zee/hub';
const WindowMethodChannel _hub =
    WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional);

String _zeeReport([Map<String, Object?> extra = const <String, Object?>{}]) =>
    jsonEncode(<String, Object?>{
      'surface': _surface,
      'isolate': identityHashCode(counter),
      'counter': counter.value,
      'configFromMain': configFromMain.value,
      'pid': pid,
      'window': _windowTag,
      'reload': 'v2-hotreload',
      ...extra,
    });

void _registerZeeExtensions() {
  developer.registerExtension('ext.zee.whoami', (m, p) async {
    return developer.ServiceExtensionResponse.result(_zeeReport());
  });
  developer.registerExtension('ext.zee.bump', (m, p) async {
    counter.value += 1;
    return developer.ServiceExtensionResponse.result(_zeeReport());
  });
  // Called on PRIMARY: push a value to the HUD over the native Hub channel.
  developer.registerExtension('ext.zee.pushConfig', (m, p) async {
    final int value = int.tryParse(p['value'] ?? '') ?? counter.value;
    final String outcome = await _pushConfigToHud(value);
    return developer.ServiceExtensionResponse.result(
        _zeeReport(<String, Object?>{'pushed': value, 'hub': outcome}));
  });
  // Per-engine screenshot through the VM service (robust under WSLg, where no
  // system window-grab tool exists): renders THIS isolate's window to a PNG.
  developer.registerExtension('ext.zee.shot', (m, p) async {
    try {
      final ctx = _shotKey.currentContext;
      if (ctx == null) {
        return developer.ServiceExtensionResponse.result(
            jsonEncode(<String, Object?>{'surface': _surface, 'error': 'no ctx'}));
      }
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      return developer.ServiceExtensionResponse.result(jsonEncode(<String, Object?>{
        'surface': _surface,
        'w': image.width,
        'h': image.height,
        'png_b64': base64Encode(bd!.buffer.asUint8List()),
      }));
    } catch (e) {
      return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{'surface': _surface, 'error': '$e'}));
    }
  });
  debugPrint('ZEEPOC-DT registered ext.zee.* surface=$_surface '
      'isolate=${identityHashCode(counter)} pid=$pid');
}

Future<String> _pushConfigToHud(int value) async {
  try {
    await _hub.invokeMethod('setConfig', value);
    debugPrint('ZEEPOC-DT pushed config=$value to HUD via Hub');
    return 'ok';
  } catch (e) {
    debugPrint('ZEEPOC-DT pushConfig FAILED: $e');
    return 'error: $e';
  }
}

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isSub = args.isNotEmpty && args.first == 'multi_window';
  debugPrint('ZEEPOC-DT main(args=$args) isSub=$isSub pid=$pid');
  if (isSub) {
    _surface = 'hud';
    _windowTag = 'sub:${args.length > 1 ? args[1] : "?"}';
    _registerZeeExtensions();
    // HUD registers the single handler on the Hub channel (the "subscriber").
    _hub.setMethodCallHandler((call) async {
      if (call.method == 'setConfig') {
        configFromMain.value = (call.arguments as num).toInt();
        debugPrint('ZEEPOC-DT HUD received config=${configFromMain.value}');
      }
      return null;
    });
    runApp(const HudApp());
  } else {
    _surface = 'primary';
    _registerZeeExtensions();
    runApp(const PrimaryApp());
  }
}

// ---------------------------------------------------------------------------
// PRIMARY (DHU) window — creates and owns the HUD window.
// ---------------------------------------------------------------------------
class PrimaryApp extends StatelessWidget {
  const PrimaryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: _shotKey, child: const PrimaryScreen()),
      );
}

class PrimaryScreen extends StatefulWidget {
  const PrimaryScreen({super.key});
  @override
  State<PrimaryScreen> createState() => _PrimaryScreenState();
}

class _PrimaryScreenState extends State<PrimaryScreen> {
  String _status = 'creating HUD window…';
  WindowController? _hud;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createHud());
  }

  Future<void> _createHud() async {
    if (_hud != null) return; // create the HUD window exactly once
    try {
      final WindowController c = await WindowController.create(
        const WindowConfiguration(arguments: 'hud', hiddenAtLaunch: true),
      );
      await c.show();
      if (!mounted) return;
      setState(() {
        _hud = c;
        _status = 'HUD window created: id=${c.windowId}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'HUD create FAILED: $e');
    }
  }

  Future<void> _bumpAndPush() async {
    counter.value += 1;
    final String r = await _pushConfigToHud(counter.value);
    if (!mounted) return;
    setState(() => _status = 'pushed counter=${counter.value} to HUD ($r)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('PRIMARY (DHU) — own engine / own isolate',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('pid=$pid   isolate(counter)=${identityHashCode(counter)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const Divider(color: Colors.white24, height: 32),
              const Text('This isolate\'s own counter:',
                  style: TextStyle(color: Colors.white70)),
              ValueListenableBuilder<int>(
                valueListenable: counter,
                builder: (_, int v, __) => Text('counter = $v',
                    style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 56,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _bumpAndPush,
                icon: const Icon(Icons.add),
                label: const Text('+1  (increment & push to HUD via Hub)'),
              ),
              const Spacer(),
              Text(_status,
                  style: const TextStyle(color: Colors.greenAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HUD window — its own engine/isolate; only learns the main value via the Hub.
// ---------------------------------------------------------------------------
class HudApp extends StatelessWidget {
  const HudApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: _shotKey, child: const HudScreen()),
      );
}

class HudScreen extends StatelessWidget {
  const HudScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('HUD — own engine / own isolate',
                  style: TextStyle(
                      color: Color(0xFFFFEB3B),
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('pid=$pid   isolate(counter)=${identityHashCode(counter)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const Divider(color: Colors.white24, height: 32),
              const Text('This isolate\'s OWN counter (independent):',
                  style: TextStyle(color: Colors.white70)),
              ValueListenableBuilder<int>(
                valueListenable: counter,
                builder: (_, int v, __) => Text('counter = $v',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 56,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              const Text('Value FROM main via Hub channel:',
                  style: TextStyle(color: Colors.white70)),
              ValueListenableBuilder<int>(
                valueListenable: configFromMain,
                builder: (_, int v, __) => Text(
                    v < 0 ? 'configFromMain = (none yet)' : 'configFromMain = $v',
                    style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 40,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
