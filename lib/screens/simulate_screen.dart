import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/hud_root.dart';
import '../l10n/app_localizations.dart';
import '../providers/car_signals.dart';
import '../providers/services.dart';
import '../services/car_signals.dart';
import '../theme/app_theme.dart';
import '../widgets/hud_preview.dart';
import '../widgets/settings_layout.dart';

/// Developer Simulate screen (Block 0026) — debug-only, drives the *real*
/// unforced CarSignals chain via [CarSignals.simulate], distinct from the
/// Config Preview's fixed-demo override in `hud_preview.dart`. Controls here
/// are the in-app equivalent of `ext.zee.inject` / the T2 ADB broadcast, so a
/// developer can watch genuine live animation/cadence/transitions on the
/// live preview below without shelling out to adb.
///
/// Only reachable from a `kDebugMode`-gated nav tile (settings_home_screen.dart)
/// — extensions and this screen alike are stripped from release builds.
class SimulateScreen extends ConsumerStatefulWidget {
  const SimulateScreen({super.key});

  @override
  ConsumerState<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends ConsumerState<SimulateScreen> {
  // Slider-only values (kW, battery %/temp, speed) have no natural "current
  // live value" widget to read back from other than the CarSignals snapshot
  // at mount time — CarSignals has no dedicated providers for values that
  // were never emitted. Blinker/charging instead read live providers
  // directly (below) since those already exist.
  late double _kw;
  late double _batteryPct;
  late double _batteryTemp;
  late double _speed;

  @override
  void initState() {
    super.initState();
    final snap = ref.read(carSignalsProvider).snapshot;
    _kw = snap.chargeKw ?? 7.4;
    _batteryPct = (snap.batteryPct ?? 72).toDouble();
    _batteryTemp = snap.batteryTempC ?? 24.0;
    _speed = (snap.speedKmh ?? 0).toDouble();
    // F1: sliders advertise defaults even when the live chain is empty —
    // seed those values once so LIVE preview / HUD pixels match the controls
    // on first paint (otherwise battery reads `--%` while the slider says 72%).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedDisplayedDefaultsIfEmpty(snap);
    });
  }

  /// Push slider-displayed battery defaults into CarSignals when nothing has
  /// been injected yet. Does not invent charging/speed — those controls already
  /// start honest (charging toggle reads live; speed is not painted on HUD).
  void _seedDisplayedDefaultsIfEmpty(CarSnapshot snap) {
    if (snap.batteryPct != null && snap.batteryTempC != null) return;
    ref.read(carSignalsProvider).simulate(
          BatteryEvent(
            levelPct: _batteryPct.round(),
            tempC: _batteryTemp,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final carSignals = ref.watch(carSignalsProvider);
    final blinkerState = ref.watch(blinkerProvider);
    final charging = ref.watch(chargingProvider) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.simulateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          // ─── Live preview — unforced, same HudRoot the real HUD renders ──
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.button),
              child: const _LiveHudPreviewBox(),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            l10n.simulateDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Blinker
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.simulateBlinkerLabel,
            children: <Widget>[
              SegmentedButton<BlinkerState>(
                segments: <ButtonSegment<BlinkerState>>[
                  ButtonSegment(
                    value: BlinkerState.off,
                    label: Text(l10n.simulateOff),
                  ),
                  ButtonSegment(
                    value: BlinkerState.left,
                    label: Text(l10n.simulateLeft),
                  ),
                  ButtonSegment(
                    value: BlinkerState.right,
                    label: Text(l10n.simulateRight),
                  ),
                  ButtonSegment(
                    value: BlinkerState.hazard,
                    label: Text(l10n.simulateHazard),
                  ),
                ],
                selected: <BlinkerState>{blinkerState},
                onSelectionChanged: (Set<BlinkerState> sel) {
                  if (sel.isEmpty) return;
                  carSignals.simulate(BlinkerEvent(sel.first));
                },
              ),
              // ValueKey hooks for agent-driven tap (one per segment), matching
              // the hud_settings_screen.dart blinker-shape convention.
              Opacity(
                opacity: 0,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      key: const ValueKey('simulate-blinker-off'),
                      onTap: () =>
                          carSignals.simulate(const BlinkerEvent(BlinkerState.off)),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('simulate-blinker-left'),
                      onTap: () =>
                          carSignals.simulate(const BlinkerEvent(BlinkerState.left)),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('simulate-blinker-right'),
                      onTap: () => carSignals.simulate(
                        const BlinkerEvent(BlinkerState.right),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                    GestureDetector(
                      key: const ValueKey('simulate-blinker-hazard'),
                      onTap: () => carSignals.simulate(
                        const BlinkerEvent(BlinkerState.hazard),
                      ),
                      child: const SizedBox(width: 1, height: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Charging
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.simulateChargingLabel,
            children: <Widget>[
              SettingsToggleRow(
                label: l10n.simulateChargingLabel,
                control: Switch(
                  key: const ValueKey('simulate-charging-toggle'),
                  value: charging,
                  onChanged: (v) => carSignals.simulate(
                    ChargeEvent(charging: v, kw: v ? _kw : null),
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: l10n.simulateChargeKwLabel,
                valueLabel: '${_kw.toStringAsFixed(1)} kW',
                minLabel: '0',
                maxLabel: '150',
                sliderKey: const ValueKey('simulate-charge-kw'),
                min: 0,
                max: 150,
                divisions: 30,
                value: _kw.clamp(0, 150),
                onChanged: (v) {
                  setState(() => _kw = v);
                  if (charging) {
                    carSignals.simulate(ChargeEvent(charging: true, kw: v));
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Battery
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.simulateBatteryLabel,
            children: <Widget>[
              SettingsSlider(
                label: l10n.simulateBatteryLabel,
                valueLabel: '${_batteryPct.round()}%',
                minLabel: '0%',
                maxLabel: '100%',
                sliderKey: const ValueKey('simulate-battery-pct'),
                min: 0,
                max: 100,
                divisions: 100,
                value: _batteryPct.clamp(0, 100),
                onChanged: (v) {
                  setState(() => _batteryPct = v);
                  carSignals.simulate(
                    BatteryEvent(levelPct: v.round(), tempC: _batteryTemp),
                  );
                },
              ),
              const SizedBox(height: Insets.md),
              SettingsSlider(
                label: l10n.simulateBatteryTempLabel,
                valueLabel: '${_batteryTemp.toStringAsFixed(0)}°C',
                minLabel: '-20°C',
                maxLabel: '60°C',
                sliderKey: const ValueKey('simulate-battery-temp'),
                min: -20,
                max: 60,
                divisions: 80,
                value: _batteryTemp.clamp(-20, 60),
                onChanged: (v) {
                  setState(() => _batteryTemp = v);
                  carSignals.simulate(
                    BatteryEvent(levelPct: _batteryPct.round(), tempC: v),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ----------------------------------------------------------------
          // Speed
          // ----------------------------------------------------------------
          SettingsSection(
            title: l10n.simulateSpeedLabel,
            children: <Widget>[
              SettingsSlider(
                label: l10n.simulateSpeedLabel,
                valueLabel: '${_speed.round()} km/h',
                minLabel: '0',
                maxLabel: '200',
                sliderKey: const ValueKey('simulate-speed'),
                min: 0,
                max: 200,
                divisions: 40,
                value: _speed.clamp(0, 200),
                onChanged: (v) {
                  setState(() => _speed = v);
                  carSignals.simulate(SpeedEvent(v.round()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grey-glass box rendering the real, UNFORCED [HudRoot] — reads live
/// CarSignals directly so the Simulate controls above are watchable in real
/// time, unlike the Config Preview which pins them to a demo scenario.
///
/// This delegates to [HudPreview] rather than re-implementing the glass box.
/// It used to be a hand-rolled copy with a hardcoded `1024 / 576` aspect, which
/// meant it showed the whole backing display instead of the optically visible
/// Safe Area *and* carried the ~2.9x mark-size exaggeration that `HudPreview`
/// now corrects — two bugs kept alive purely by the duplication.
class _LiveHudPreviewBox extends StatelessWidget {
  const _LiveHudPreviewBox();

  @override
  Widget build(BuildContext context) {
    return const HudPreview(
      forceDemoSignals: false,
      badge: HudPreviewBadge.liveSimulated,
    );
  }
}
