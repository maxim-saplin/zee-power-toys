import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../services/config_store.dart';

/// The desktop "Hub": a native-mediated cross-engine channel.
/// Routing is done inside the native ChannelRegistry — not via shared Dart heap.
/// Unidirectional: DHU invokes, HUD handles.
const String kHubChannel = 'zee/hub';
const WindowMethodChannel _hub =
    WindowMethodChannel(kHubChannel, mode: ChannelMode.unidirectional);

/// DHU side: push a changed AppConfig event to the HUD isolate.
/// Only the serialized event crosses — never a shared object (ADR 0003).
Future<void> pushConfigToHud(AppConfig c) async {
  try {
    await _hub.invokeMethod('setConfig', jsonEncode(c.toJson()));
  } catch (e) {
    // HUD window may not be ready yet; log but don't crash.
    debugPrint('zee/hub pushConfigToHud failed: $e');
  }
}

/// HUD side: register a handler that decodes arriving setConfig events and
/// calls [onConfig]. Must be called during HUD startup only.
void listenForConfig(void Function(AppConfig) onConfig) {
  _hub.setMethodCallHandler((call) async {
    if (call.method == 'setConfig') {
      try {
        final decoded = AppConfig.fromJson(
          jsonDecode(call.arguments as String) as Map<String, Object?>,
        );
        onConfig(decoded);
      } catch (_) {
        // Ignore malformed relay messages.
      }
    }
    return null;
  });
}
