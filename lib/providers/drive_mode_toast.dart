import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/car_signals.dart';
import 'services.dart';

/// Active drive-mode toast payload (0104). Null = hidden.
class DriveModeToast {
  const DriveModeToast({
    required this.mode,
    required this.shownAt,
    this.hold = const Duration(seconds: 5),
  });

  final DriveMode mode;
  final DateTime shownAt;
  final Duration hold;
}

/// Change-only toast: cold-open / first snapshot baseline does **not** show;
/// subsequent [DriveModeEvent]s with a different known mode do.
final driveModeToastProvider =
    NotifierProvider<DriveModeToastNotifier, DriveModeToast?>(
  DriveModeToastNotifier.new,
);

class DriveModeToastNotifier extends Notifier<DriveModeToast?> {
  DriveMode? _seen;
  bool _bootstrapped = false;
  Timer? _hide;
  StreamSubscription<CarSignalEvent>? _sub;

  @override
  DriveModeToast? build() {
    final signals = ref.read(carSignalsProvider);
    bootstrap(signals.snapshot.driveMode);
    _sub?.cancel();
    _sub = signals.events.listen((e) {
      if (e is DriveModeEvent) onEvent(e.mode);
    });
    ref.onDispose(() {
      _sub?.cancel();
      _hide?.cancel();
    });
    return null;
  }

  void bootstrap(DriveMode mode) {
    if (_bootstrapped) return;
    _bootstrapped = true;
    if (mode != DriveMode.unknown) _seen = mode;
  }

  void onEvent(DriveMode mode) {
    if (!_bootstrapped) {
      bootstrap(mode);
      return;
    }
    if (mode == DriveMode.unknown) return;
    if (mode == _seen) return;
    _seen = mode;
    _hide?.cancel();
    state = DriveModeToast(mode: mode, shownAt: DateTime.now());
    _hide = Timer(const Duration(seconds: 5), () {
      state = null;
    });
  }

  void debugClear() {
    _hide?.cancel();
    state = null;
  }

  void debugSetSeen(DriveMode mode) {
    _bootstrapped = true;
    _seen = mode == DriveMode.unknown ? null : mode;
  }
}
