/// Polls [condition] until it returns true or [timeout] elapses.
/// Avoids fixed-duration sleeps which cause non-deterministic failures when
/// flutter test runs files in parallel (each gets its own isolate).
Future<void> pumpUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('pumpUntil timed out after $timeout');
    }
    await Future<void>.delayed(interval);
  }
}
