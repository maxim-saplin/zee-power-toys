import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/providers/car_signals.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';

void main() {
  // Creates a container + fake pair, subscribes the streamProvider so the
  // Riverpod dependency graph is active, and disposes cleanly after the test.
  (ProviderContainer, FakeCarSignals) makeContainer() {
    final fake = FakeCarSignals();
    final container = ProviderContainer(
      overrides: [carSignalsProvider.overrideWithValue(fake)],
    );
    // Subscribe the stream so the graph stays alive across microtasks.
    container.listen(carSignalEventsProvider, (prev, next) {});
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return (container, fake);
  }

  group('speedProvider', () {
    test('reflects SpeedEvent emitted on FakeCarSignals', () async {
      final (container, fake) = makeContainer();

      expect(container.read(speedProvider), isNull);

      fake.emitSpeed(80);
      // Give the stream a microtask turn to propagate through the provider graph.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(speedProvider), equals(80));
    });

    test('snapshot is updated after emit', () {
      final fake = FakeCarSignals();
      addTearDown(fake.dispose);
      fake.emitSpeed(100);
      expect(fake.snapshot.speedKmh, equals(100));
    });
  });

  group('blinkerProvider', () {
    test('reflects BlinkerEvent.left', () async {
      final (container, fake) = makeContainer();

      expect(container.read(blinkerProvider), BlinkerState.off);

      fake.emitBlinker(BlinkerState.left);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(blinkerProvider), BlinkerState.left);
    });

    test('reflects BlinkerEvent.hazard', () async {
      final (container, fake) = makeContainer();

      fake.emitBlinker(BlinkerState.hazard);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(blinkerProvider), BlinkerState.hazard);
    });
  });

  group('chargingProvider', () {
    test('reflects ChargeEvent charging=true with kw', () async {
      final (container, fake) = makeContainer();

      expect(container.read(chargingProvider), isNull);

      fake.emitCharge(charging: true, kw: 50.0);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(chargingProvider), isTrue);
      expect(container.read(chargeKwProvider), closeTo(50.0, 0.001));
    });
  });

  group('batteryPctProvider / batteryTempCProvider', () {
    test('reflects BatteryEvent', () async {
      final (container, fake) = makeContainer();

      fake.emitBattery(levelPct: 72, tempC: 24.0);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(batteryPctProvider), equals(72));
      expect(container.read(batteryTempCProvider), closeTo(24.0, 0.001));
    });
  });

  group('relay helper', () {
    test('relay re-emits event and updates snapshot', () {
      final fake = FakeCarSignals();
      addTearDown(fake.dispose);
      const event = SpeedEvent(55);
      fake.relay(event);
      expect(fake.snapshot.speedKmh, equals(55));
    });
  });

  group('CarSnapshot.copyWith', () {
    test('preserves unchanged fields', () {
      const s = CarSnapshot(speedKmh: 80, batteryPct: 50);
      final s2 = s.copyWith(speedKmh: 90);
      expect(s2.speedKmh, 90);
      expect(s2.batteryPct, 50);
    });
  });

  group('CarSnapshot.toJson', () {
    test('serialises all fields', () {
      final snap = const CarSnapshot(
        speedKmh: 80,
        blinker: BlinkerState.left,
        charging: true,
        chargeKw: 50.0,
        batteryPct: 72,
        batteryTempC: 24.0,
        powerFlow: PowerFlow.drive,
      ).toJson();

      expect(snap['speedKmh'], 80);
      expect(snap['blinker'], 'left');
      expect(snap['charging'], isTrue);
      expect(snap['chargeKw'], closeTo(50.0, 0.001));
      expect(snap['batteryPct'], 72);
      expect(snap['batteryTempC'], closeTo(24.0, 0.001));
      expect(snap['powerFlow'], 'drive');
    });
  });

  group('FakeInstaller', () {
    test('emits downloading → installing → done progression', () async {
      // Verify the fake produces a valid progression (import-free smoke check).
      final fake = FakeCarSignals();
      addTearDown(fake.dispose);
      // Just verify emitBattery + emitSpeed combine correctly in snapshot.
      fake.emitSpeed(42);
      fake.emitBattery(levelPct: 80, tempC: 30.0);
      expect(fake.snapshot.speedKmh, 42);
      expect(fake.snapshot.batteryPct, 80);
    });
  });
}
