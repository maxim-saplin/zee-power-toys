// =============================================================================
// THROWAWAY PoC — Approach B: CUSTOM two-engine GTK runner (desktop twin of
// ADR 0005 "own the host"). No package. The runner (linux/runner/
// my_application.cc) creates TWO independent FlEngines (via two fl_view_new) in
// the SAME process — a PRIMARY window and a HUD window — distinguished by the
// Dart entrypoint argument "hud". This mirrors Android's FlutterEngineGroup:
// two isolates, one process, one Dart VM service.
// =============================================================================

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show pid;

import 'package:flutter/material.dart';

/// Per-isolate "shared-looking" counter — diverges across the two engines.
final ValueNotifier<int> counter = ValueNotifier<int>(0);
String _surface = 'unknown';

String _report() => jsonEncode(<String, Object?>{
      'surface': _surface,
      'isolate': identityHashCode(counter),
      'counter': counter.value,
      'pid': pid,
      'mechanism': 'custom-gtk-runner',
    });

void _registerZee() {
  developer.registerExtension('ext.zee.whoami', (m, p) async {
    return developer.ServiceExtensionResponse.result(_report());
  });
  developer.registerExtension('ext.zee.bump', (m, p) async {
    counter.value += 1;
    return developer.ServiceExtensionResponse.result(_report());
  });
  debugPrint('ZEEPOC-B registered ext.zee.* surface=$_surface '
      'isolate=${identityHashCode(counter)} pid=$pid');
}

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isHud = args.contains('hud');
  _surface = isHud ? 'hud' : 'primary';
  debugPrint('ZEEPOC-B main(args=$args) surface=$_surface pid=$pid');
  _registerZee();
  runApp(isHud
      ? const BApp(
          title: 'HUD',
          bg: Color(0xFF1A0E10),
          titleColor: Color(0xFFFFEB3B),
          counterColor: Colors.orangeAccent)
      : const BApp(
          title: 'PRIMARY (DHU)',
          bg: Color(0xFF101418),
          titleColor: Colors.white,
          counterColor: Colors.cyanAccent));
}

class BApp extends StatelessWidget {
  const BApp({
    super.key,
    required this.title,
    required this.bg,
    required this.titleColor,
    required this.counterColor,
  });
  final String title;
  final Color bg;
  final Color titleColor;
  final Color counterColor;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('$title — own engine / own isolate',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Approach B — custom GTK two-engine runner',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 10),
                  Text('pid=$pid   isolate(counter)=${identityHashCode(counter)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                  const Divider(color: Colors.white24, height: 32),
                  const Text("This isolate's own counter:",
                      style: TextStyle(color: Colors.white70)),
                  ValueListenableBuilder<int>(
                    valueListenable: counter,
                    builder: (_, int v, __) => Text('counter = $v',
                        style: TextStyle(
                            color: counterColor,
                            fontSize: 52,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
