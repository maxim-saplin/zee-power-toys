import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show pid;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../services/config_store.dart';

/// Register ext.zee.* VM-service extensions for [surface] (either 'dhu' or 'hud').
///
/// Both isolates register the same set so the Feedback Loop can drive and read
/// each surface independently. [shotKey] must wrap the root RepaintBoundary.
/// [onSetConfig] is optional (DHU can pass null; the store.changes subscription
/// already relays to HUD).
void registerZeeExtensions({
  required String surface,
  required ConfigStore store,
  required GlobalKey shotKey,
  Future<void> Function(AppConfig)? onSetConfig,
}) {
  developer.registerExtension('ext.zee.whoami', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'surface': surface,
        'isolate': identityHashCode(store),
        'pid': pid,
        'hudBoxOn': store.value.hudBoxOn,
      }),
    );
  });

  developer.registerExtension('ext.zee.dumpState', (method, params) async {
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  developer.registerExtension('ext.zee.setConfig', (method, params) async {
    final raw = params['hudBoxOn'];
    final parsed = raw == 'true';
    final next = store.value.copyWith(hudBoxOn: parsed);
    await store.setConfig(next);
    if (onSetConfig != null) await onSetConfig(next);
    return developer.ServiceExtensionResponse.result(
      _dumpStateJson(surface, store),
    );
  });

  // Per-engine screenshot via RepaintBoundary → PNG → base64.
  // pixelRatio=1.0 keeps payloads small; this is diagnostic-only.
  developer.registerExtension('ext.zee.shot', (method, params) async {
    try {
      final ctx = shotKey.currentContext;
      if (ctx == null) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(<String, Object?>{'surface': surface, 'error': 'no ctx'}),
        );
      }
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{
          'surface': surface,
          'w': image.width,
          'h': image.height,
          'png_b64': base64Encode(bd!.buffer.asUint8List()),
        }),
      );
    } catch (e) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(<String, Object?>{'surface': surface, 'error': '$e'}),
      );
    }
  });
}

String _dumpStateJson(String surface, ConfigStore store) =>
    jsonEncode(<String, Object?>{
      'surface': surface,
      'hudBoxOn': store.value.hudBoxOn,
    });
