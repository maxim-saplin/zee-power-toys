import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../installer.dart';

/// Android implementation of [Installer].
///
/// Communicates with the native Kotlin [InstallerController] via two channels:
///   - MethodChannel  "zee/installer"        — start(url)
///   - EventChannel   "zee/installer/events" — multiplexed progress stream
///
/// Block 0084: Flutter's EventChannel allows only one active listener. Opening
/// a second [receiveBroadcastStream] cancelled the first (Update looked
/// aborted; progress landed on the wrong card).  This adapter keeps **one**
/// shared native subscription while any install is active and fans events out
/// by the `url` field that Kotlin attaches to every progress map.  Installs are
/// started only via the MethodChannel (listen args are unused).
class NativeInstaller implements Installer {
  NativeInstaller({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method = methodChannel ?? const MethodChannel('zee/installer'),
        _events = eventChannel ?? const EventChannel('zee/installer/events');

  final MethodChannel _method;
  final EventChannel _events;

  /// url → controllers waiting for that job's progress.
  final Map<String, Set<StreamController<InstallProgress>>> _listeners =
      <String, Set<StreamController<InstallProgress>>>{};

  StreamSubscription<dynamic>? _sharedSub;

  /// Test seam: drop shared subscription + listener map.
  @visibleForTesting
  void resetForTest() {
    _sharedSub?.cancel();
    _sharedSub = null;
    for (final set in _listeners.values) {
      for (final c in set) {
        if (!c.isClosed) c.close();
      }
    }
    _listeners.clear();
  }

  @visibleForTesting
  int get activeListenerCount =>
      _listeners.values.fold<int>(0, (n, s) => n + s.length);

  @visibleForTesting
  bool get hasSharedSubscription => _sharedSub != null;

  void _ensureSharedSubscription() {
    if (_sharedSub != null) return;
    // No listen args — native must not start a job from onListen.
    final raw = _events.receiveBroadcastStream();
    _sharedSub = raw.listen(
      _dispatchEvent,
      onError: (Object err, StackTrace st) {
        final failed = InstallProgress(
          phase: InstallPhase.failed,
          fraction: 0.0,
          message: err.toString(),
        );
        for (final set in _listeners.values.toList()) {
          for (final c in set.toList()) {
            if (!c.isClosed) {
              c.add(failed);
              c.close();
            }
          }
        }
        _listeners.clear();
        _sharedSub = null;
      },
      onDone: () {
        for (final set in _listeners.values.toList()) {
          for (final c in set.toList()) {
            if (!c.isClosed) c.close();
          }
        }
        _listeners.clear();
        _sharedSub = null;
      },
      cancelOnError: false,
    );
  }

  void _dispatchEvent(dynamic event) {
    if (event is! Map) return;
    final url = event['url'] as String? ?? '';
    final phase = _parsePhase(event['phase'] as String? ?? 'downloading');
    final fraction = (event['fraction'] as num?)?.toDouble() ?? 0.0;
    final message = event['message'] as String?;
    final progress = InstallProgress(
      phase: phase,
      fraction: fraction,
      message: message,
    );

    final targets = url.isEmpty
        ? _listeners.values.expand((s) => s).toList()
        : (_listeners[url]?.toList() ??
            const <StreamController<InstallProgress>>[]);

    for (final c in targets) {
      if (c.isClosed) continue;
      c.add(progress);
      if (phase == InstallPhase.done || phase == InstallPhase.failed) {
        c.close();
      }
    }

    if (phase == InstallPhase.done || phase == InstallPhase.failed) {
      if (url.isNotEmpty) {
        _listeners.remove(url);
      }
      if (_listeners.isEmpty) {
        _sharedSub?.cancel();
        _sharedSub = null;
      }
    }
  }

  void _register(String url, StreamController<InstallProgress> controller) {
    (_listeners[url] ??= <StreamController<InstallProgress>>{}).add(controller);
    controller.onCancel = () {
      final set = _listeners[url];
      set?.remove(controller);
      if (set != null && set.isEmpty) {
        _listeners.remove(url);
      }
      // Keep the shared native subscription while *any* job still has a
      // listener.  Do not cancel it here when the map goes empty mid-flight —
      // the job may still emit a terminal event, and cancelling would hit
      // native onCancel (harmless after 0084, but we would miss the event if
      // a new listen is not yet open).  Tear happens after terminal dispatch.
    };
  }

  @override
  Stream<InstallProgress> install(GithubAsset asset) {
    final String url = asset.downloadUrl;
    _ensureSharedSubscription();

    final controller = StreamController<InstallProgress>();
    _register(url, controller);

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
      final set = _listeners[url];
      set?.remove(controller);
      if (set != null && set.isEmpty) _listeners.remove(url);
      if (_listeners.isEmpty) {
        _sharedSub?.cancel();
        _sharedSub = null;
      }
    });

    return controller.stream;
  }

  /// Inject a native-shaped event (tests / no platform channel).
  @visibleForTesting
  void debugDispatch(Map<String, Object?> event) => _dispatchEvent(event);

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
