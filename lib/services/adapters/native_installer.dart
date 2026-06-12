import 'dart:async';

import 'package:flutter/services.dart';

import '../installer.dart';

/// Android implementation of [Installer].
///
/// Communicates with the native Kotlin [InstallerController] via two channels:
///   - MethodChannel  "zee/installer"        — start(url)
///   - EventChannel   "zee/installer/events" — progress stream
///
/// The resolved LFS raw-content URL is passed directly; the native side
/// downloads the APK and launches PackageInstaller session API (or falls back
/// to ACTION_VIEW).  URL form:
///   `https://media.githubusercontent.com/media/<repo>/<branch>/<path>`
class NativeInstaller implements Installer {
  static const _method = MethodChannel('zee/installer');
  static const _events = EventChannel('zee/installer/events');

  @override
  Stream<InstallProgress> install(GithubAsset asset) {
    final String url = asset.downloadUrl;

    // Open the native event stream before invoking start() so no progress
    // events are missed between the method call returning and the stream setup.
    final rawStream = _events.receiveBroadcastStream(<String, Object?>{
      'url': url,
    });

    // Transform raw Map events → typed InstallProgress objects.
    final controller = StreamController<InstallProgress>();

    StreamSubscription<dynamic>? sub;
    sub = rawStream.listen(
      (dynamic event) {
        if (event is Map) {
          final phase = _parsePhase(event['phase'] as String? ?? 'downloading');
          final fraction = (event['fraction'] as num?)?.toDouble() ?? 0.0;
          final message = event['message'] as String?;
          controller.add(InstallProgress(
            phase: phase,
            fraction: fraction,
            message: message,
          ));
          // Close the controller on terminal states so callers see stream end.
          if (phase == InstallPhase.done || phase == InstallPhase.failed) {
            sub?.cancel();
            controller.close();
          }
        }
      },
      onError: (Object err) {
        controller.add(InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0.0,
          message: err.toString(),
        ));
        controller.close();
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
      cancelOnError: false,
    );

    // Kick off the native download+install. Errors from the method call itself
    // (e.g. channel not found before the engine is ready) are surfaced as a
    // failed progress event so the UI always sees a clean stream.
    _method.invokeMethod<void>('start', <String, Object?>{
      'url': url,
    }).catchError((Object err) {
      if (!controller.isClosed) {
        controller.add(InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0.0,
          message: 'channel error: $err',
        ));
        controller.close();
      }
    });

    return controller.stream;
  }

  static InstallPhase _parsePhase(String raw) {
    switch (raw) {
      case 'downloading':
        return InstallPhase.downloading;
      case 'installing':
        return InstallPhase.installing;
      case 'done':
        return InstallPhase.done;
      case 'failed':
        return InstallPhase.failed;
      default:
        return InstallPhase.downloading;
    }
  }
}
