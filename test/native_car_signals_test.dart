// Unit tests for NativeCarSignals event decoding.
//
// NativeCarSignals receives discriminated maps from the Kotlin EventChannel.
// These tests verify every event type decodes correctly to a CarSignalEvent
// and updates CarSnapshot — without a real channel or Flutter binding.
//
// The decoder is exposed via @visibleForTesting onNativeEvent(); the
// MethodChannel/EventChannel registration in the constructor is skipped by
// calling onNativeEvent directly, not via the real channel.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:zee_power_toys/services/adapters/native_car_signals.dart';
import 'package:zee_power_toys/services/car_signals.dart';

void main() {
  // Stub the MethodChannel so 'start' doesn't crash in the test environment.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Suppress the MissingPluginException from EventChannel/MethodChannel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('zee/car_signals'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zee/car_signals'), null);
  });

  group('NativeCarSignals.onNativeEvent decoding', () {
    late NativeCarSignals sut;
    late List<CarSignalEvent> received;

    setUp(() {
      sut = NativeCarSignals();
      received = [];
      sut.events.listen(received.add);
    });

    tearDown(() => sut.dispose());

    test('speed: kmh decoded correctly', () async {
      sut.onNativeEvent({'type': 'speed', 'kmh': 80});
      await Future<void>.value();
      expect(received, hasLength(1));
      expect((received.first as SpeedEvent).kmh, 80);
      expect(sut.snapshot.speedKmh, 80);
    });

    test('speed: double kmh cast to int', () async {
      sut.onNativeEvent({'type': 'speed', 'kmh': 80.9});
      await Future<void>.value();
      expect((received.first as SpeedEvent).kmh, 80);
    });

    test('blinker left decoded', () async {
      sut.onNativeEvent({'type': 'blinker', 'state': 'left'});
      await Future<void>.value();
      expect((received.first as BlinkerEvent).state, BlinkerState.left);
      expect(sut.snapshot.blinker, BlinkerState.left);
    });

    test('blinker hazard decoded', () async {
      sut.onNativeEvent({'type': 'blinker', 'state': 'hazard'});
      await Future<void>.value();
      expect((received.first as BlinkerEvent).state, BlinkerState.hazard);
    });

    test('charge true with all fields', () async {
      sut.onNativeEvent({
        'type': 'charge',
        'charging': true,
        'volts': 400.0,
        'amps': 20.5,
        'kw': 8.2,
      });
      await Future<void>.value();
      final e = received.first as ChargeEvent;
      expect(e.charging, true);
      expect(e.kw, closeTo(8.2, 0.001));
      expect(e.volts, closeTo(400.0, 0.001));
      expect(sut.snapshot.charging, true);
      expect(sut.snapshot.chargeKw, closeTo(8.2, 0.001));
    });

    test('charge false', () async {
      sut.onNativeEvent({'type': 'charge', 'charging': false});
      await Future<void>.value();
      expect((received.first as ChargeEvent).charging, false);
    });

    test('battery: levelPct and tempC', () async {
      sut.onNativeEvent({'type': 'battery', 'levelPct': 75, 'tempC': 27.5});
      await Future<void>.value();
      final e = received.first as BatteryEvent;
      expect(e.levelPct, 75);
      expect(e.tempC, closeTo(27.5, 0.001));
      expect(sut.snapshot.batteryPct, 75);
      expect(sut.snapshot.batteryTempC, closeTo(27.5, 0.001));
    });

    test('powerFlow drive', () async {
      sut.onNativeEvent({'type': 'powerFlow', 'flow': 'drive'});
      await Future<void>.value();
      expect((received.first as PowerFlowEvent).flow, PowerFlow.drive);
      expect(sut.snapshot.powerFlow, PowerFlow.drive);
    });

    test('powerFlow regen', () async {
      sut.onNativeEvent({'type': 'powerFlow', 'flow': 'regen'});
      await Future<void>.value();
      expect((received.first as PowerFlowEvent).flow, PowerFlow.regen);
    });

    test('unknown type ignored — no event emitted, no crash', () async {
      sut.onNativeEvent({'type': 'unknown_future_type', 'x': 1});
      await Future<void>.value();
      expect(received, isEmpty);
    });

    test('null kmh defaults to 0', () async {
      sut.onNativeEvent({'type': 'speed', 'kmh': null});
      await Future<void>.value();
      expect((received.first as SpeedEvent).kmh, 0);
    });

    test('non-Map raw value ignored', () async {
      sut.onNativeEvent('not a map');
      await Future<void>.value();
      expect(received, isEmpty);
    });

    test('snapshot accumulates across multiple events', () async {
      sut.onNativeEvent({'type': 'speed', 'kmh': 90});
      sut.onNativeEvent({'type': 'blinker', 'state': 'right'});
      sut.onNativeEvent({'type': 'battery', 'levelPct': 60, 'tempC': 30.0});
      await Future<void>.value();
      expect(sut.snapshot.speedKmh, 90);
      expect(sut.snapshot.blinker, BlinkerState.right);
      expect(sut.snapshot.batteryPct, 60);
    });
  });
}
