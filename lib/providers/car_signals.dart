import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/car_signals.dart';
import 'services.dart';

/// All [CarSignalEvent]s from the injected [CarSignals] service.
final carSignalEventsProvider = StreamProvider<CarSignalEvent>((ref) {
  return ref.watch(carSignalsProvider).events;
});

/// Latest speed in km/h; null until a SpeedEvent has been received.
/// Falls back to snapshot so that reads before the first stream emission work.
final speedProvider = Provider<int?>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is SpeedEvent) return event.kmh;
  return ref.watch(carSignalsProvider).snapshot.speedKmh;
});

/// Current blinker state; falls back to snapshot.
final blinkerProvider = Provider<BlinkerState>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is BlinkerEvent) return event.state;
  return ref.watch(carSignalsProvider).snapshot.blinker;
});

/// Charging flag; null until a ChargeEvent has been received.
final chargingProvider = Provider<bool?>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is ChargeEvent) return event.charging;
  return ref.watch(carSignalsProvider).snapshot.charging;
});

/// Latest charging power in kW; null when not charging or no event yet.
final chargeKwProvider = Provider<double?>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is ChargeEvent) return event.kw;
  return ref.watch(carSignalsProvider).snapshot.chargeKw;
});

/// Battery level in percent; null until a BatteryEvent has been received.
final batteryPctProvider = Provider<int?>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is BatteryEvent) return event.levelPct;
  return ref.watch(carSignalsProvider).snapshot.batteryPct;
});

/// Battery temperature in °C; null until a BatteryEvent has been received.
final batteryTempCProvider = Provider<double?>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is BatteryEvent) return event.tempC;
  return ref.watch(carSignalsProvider).snapshot.batteryTempC;
});

/// Current power-flow state (drive/regen/standstill/unknown); falls back to snapshot.
final powerFlowProvider = Provider<PowerFlow>((ref) {
  final event = ref.watch(carSignalEventsProvider).value;
  if (event is PowerFlowEvent) return event.flow;
  return ref.watch(carSignalsProvider).snapshot.powerFlow;
});
