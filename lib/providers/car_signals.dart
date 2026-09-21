import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/car_signals.dart';
import 'services.dart';

/// All [CarSignalEvent]s from the injected [CarSignals] service.
///
/// Watch this to rebuild on any event; **read values from [CarSignals.snapshot]**.
/// Using `AsyncValue.value` as the source of truth was wrong: the latest stream
/// event may be a Speed/Battery tick (or a ChargeEvent with null kW), so
/// Diagnostics Energy showed "—" while snapshot/raw still had charging + kW.
final carSignalEventsProvider = StreamProvider<CarSignalEvent>((ref) {
  return ref.watch(carSignalsProvider).events;
});

void _touchEvents(Ref ref) {
  ref.watch(carSignalEventsProvider);
}

/// Latest speed in km/h; null until known.
final speedProvider = Provider<int?>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.speedKmh;
});

/// Current blinker state.
final blinkerProvider = Provider<BlinkerState>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.blinker;
});

/// Charging flag — always true/false (never null).
final chargingProvider = Provider<bool>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.charging;
});

/// Instant charge/discharge power in kW (signed); null until known.
final chargeKwProvider = Provider<double?>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.chargeKw;
});

/// Battery level in percent; null until known.
final batteryPctProvider = Provider<int?>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.batteryPct;
});

/// Battery temperature in °C; null until known.
final batteryTempCProvider = Provider<double?>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.batteryTempC;
});

/// Power-flow enum from snapshot.
final powerFlowProvider = Provider<PowerFlow>((ref) {
  _touchEvents(ref);
  return ref.watch(carSignalsProvider).snapshot.powerFlow;
});

/// Which car-signal source is live: 'adaptapi' | 'simulated' | 'fake'.
final signalSourceProvider = FutureProvider<String>((ref) {
  return ref.watch(carSignalsProvider).sourceKind;
});
