import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// THROWAWAY PoC — multi-display Flutter for zee-power-toys.
//
// One Dart library, two entrypoints:
//   main()    -> PRIMARY display app (DHU-touchscreen analog) + Minimap control
//   hudMain() -> SECONDARY display overlay (HUD analog), transparent background
//
// `tick` is the "single source of truth" probe. In a SINGLE-engine / single-
// isolate world it is shared by every view. With TWO engines each isolate owns
// its own copy, so the values visibly diverge — that is how we tell them apart.
// =============================================================================

final ValueNotifier<int> tick = ValueNotifier<int>(0);

const List<Color> kPalette = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF8E24AA), // purple
  Color(0xFF1E88E5), // blue
  Color(0xFF00ACC1), // cyan
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
];

/// Lean Dart -> native control surface for the native "Minimap" stand-in.
const MethodChannel kMinimap = MethodChannel('zee/minimap');

void _startClock(String who) {
  Timer.periodic(const Duration(milliseconds: 500), (_) {
    tick.value = tick.value + 1;
  });
  debugPrint('ZEEPOC-DART clock started for $who '
      '(isolate=${identityHashCode(tick)})');
}

// Feedback Loop (ADR 0004) probe: register custom VM-service extensions in the
// CURRENT isolate. BOTH entrypoints call this, so the primary and the HUD
// isolate each expose their OWN ext.zee.* handlers. The decisive question is
// whether ONE external Dart VM service can address EACH surface independently
// via the per-call `isolateId` — including the secondary/HUD isolate spawned
// by FlutterEngineGroup.
//   ext.zee.whoami -> {surface, isolate, tick}                 (read probe)
//   ext.zee.bump   -> increments THIS isolate's tick, returns new value (write)
String _zeeReport(String surface) => jsonEncode(<String, Object?>{
      'surface': surface,
      'isolate': identityHashCode(tick),
      'tick': tick.value,
    });

void _registerZeeExtensions(String surface) {
  developer.registerExtension(
    'ext.zee.whoami',
    (String method, Map<String, String> parameters) async {
      return developer.ServiceExtensionResponse.result(_zeeReport(surface));
    },
  );
  developer.registerExtension(
    'ext.zee.bump',
    (String method, Map<String, String> parameters) async {
      tick.value = tick.value + 1;
      return developer.ServiceExtensionResponse.result(_zeeReport(surface));
    },
  );
  debugPrint('ZEEPOC-DART registered ext.zee.* for surface=$surface '
      '(isolate=${identityHashCode(tick)})');
}

// ---------------------------------------------------------------------------
// PRIMARY entrypoint
// ---------------------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerZeeExtensions('primary');
  _startClock('PRIMARY');
  runApp(const PrimaryApp());
}

class PrimaryApp extends StatelessWidget {
  const PrimaryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrimaryScreen(),
    );
  }
}

class PrimaryScreen extends StatefulWidget {
  const PrimaryScreen({super.key});
  @override
  State<PrimaryScreen> createState() => _PrimaryScreenState();
}

class _PrimaryScreenState extends State<PrimaryScreen> {
  int _boundsIdx = 0;
  double _hue = 200;
  String _lastCall = '(none)';

  // Cycle through a few bounds rectangles for setMinimapBounds.
  static const List<List<int>> _boundsCycle = <List<int>>[
    <int>[40, 40, 480, 260],
    <int>[700, 60, 520, 300],
    <int>[260, 360, 760, 320],
    <int>[0, 0, 1280, 720],
  ];

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      final Object? r = await kMinimap.invokeMethod<Object?>(method, args);
      setState(() => _lastCall = '$method ${args ?? ''} -> $r');
    } on PlatformException catch (e) {
      setState(() => _lastCall = '$method ERROR ${e.code} ${e.message}');
    } catch (e) {
      setState(() => _lastCall = '$method ERROR $e');
    }
    debugPrint('ZEEPOC-DART minimap call: $_lastCall');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('PRIMARY display (DHU)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Shared-state probe (this isolate):',
                  style: TextStyle(color: Colors.white70)),
              ValueListenableBuilder<int>(
                valueListenable: tick,
                builder: (_, int v, __) => Row(
                  children: <Widget>[
                    Text('tick = $v',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 24),
                    Container(
                        width: 64,
                        height: 64,
                        color: kPalette[v % kPalette.length]),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 32),
              const Text('Dart -> native Minimap control (Exp 3)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () => _invoke('setMinimap', {'enabled': true}),
                    child: const Text('setMinimap(true)'),
                  ),
                  ElevatedButton(
                    onPressed: () => _invoke('setMinimap', {'enabled': false}),
                    child: const Text('setMinimap(false)'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _boundsIdx = (_boundsIdx + 1) % _boundsCycle.length;
                      final List<int> b = _boundsCycle[_boundsIdx];
                      _invoke('setMinimapBounds',
                          {'x': b[0], 'y': b[1], 'w': b[2], 'h': b[3]});
                    },
                    child: const Text('setMinimapBounds (cycle)'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _hue = (_hue + 40) % 360;
                      _invoke('setMinimapParam', {'key': 'hue', 'value': _hue});
                    },
                    child: const Text('setMinimapParam hue+'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Idempotency probe: 2nd identical call must be a native no-op.
                      await _invoke('setMinimap', {'enabled': true});
                      await _invoke('setMinimap', {'enabled': true});
                    },
                    child: const Text('idempotency x2'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('last: $_lastCall',
                  style: const TextStyle(color: Colors.greenAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECONDARY / HUD overlay entrypoint (its own isolate when in its own engine)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void hudMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerZeeExtensions('hud');
  _startClock('HUD');
  runApp(const HudApp());
}

class HudApp extends StatelessWidget {
  const HudApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HudOverlay(),
    );
  }
}

class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key});
  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  bool _blink = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 600),
        (_) => setState(() => _blink = !_blink));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so the native Minimap surface shows through.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          // Blinker dot (semi-transparent): Flutter pixels composited on top.
          Positioned(
            top: 40,
            left: 40,
            child: AnimatedOpacity(
              opacity: _blink ? 1.0 : 0.15,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xCCFFEB3B),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: Color(0x66FFEB3B),
                        blurRadius: 24,
                        spreadRadius: 8)
                  ],
                ),
              ),
            ),
          ),
          // Semi-transparent HUD label + this isolate's own tick value.
          Positioned(
            right: 30,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0x66000000),
              child: ValueListenableBuilder<int>(
                valueListenable: tick,
                builder: (_, int v, __) => Text('HUD overlay  tick=$v',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
