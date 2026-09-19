import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/speedcam.dart';
import 'services.dart';

/// Live Speedcam snapshots from the injected [SpeedcamService].
final speedcamSnapshotsProvider = StreamProvider<SpeedcamSnapshot>((ref) {
  return ref.watch(speedcamServiceProvider).snapshots;
});

/// Latest danger (nearest cam); null when no host pose or disabled.
final speedcamDangerProvider = Provider<SpeedcamDanger?>((ref) {
  final async = ref.watch(speedcamSnapshotsProvider);
  return async.value?.danger ??
      ref.watch(speedcamServiceProvider).snapshot.danger;
});

/// Latest full snapshot for dump/UI.
final speedcamSnapshotProvider = Provider<SpeedcamSnapshot>((ref) {
  final async = ref.watch(speedcamSnapshotsProvider);
  return async.value ?? ref.watch(speedcamServiceProvider).snapshot;
});
