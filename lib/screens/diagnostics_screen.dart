import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/car_signals.dart';
import '../providers/hud_geometry.dart';
import '../providers/usb_mode.dart';
import '../services/car_signals.dart';
import '../services/usb_mode.dart';
import '../theme/app_theme.dart';

/// Live DHU diagnostics dashboard — shows current car-signal values grouped by
/// domain.  Updates via [ref.watch] on the CarSignals providers; no polling
/// needed because the providers react to the stream from FakeCarSignals (T1) or
/// NativeCarSignals (T2).
///
/// This screen is intentionally READ-ONLY (Block 0023 QA2-2): write-capable
/// controls (USB mode selector) are now on the dedicated USB/ADB hub tile.
/// Only live read-only signal rows appear here.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Read all live providers — each rebuilds only the widget that watches it.
    final speed = ref.watch(speedProvider);
    final blinker = ref.watch(blinkerProvider);
    final charging = ref.watch(chargingProvider);
    final chargeKw = ref.watch(chargeKwProvider);
    final batteryPct = ref.watch(batteryPctProvider);
    final batteryTempC = ref.watch(batteryTempCProvider);
    final powerFlow = ref.watch(powerFlowProvider);

    // Read-only USB mode — no writes here; use nav-usb hub tile for writes.
    final usbPort = ref.watch(usbModeProvider);

    // Which signal source is actually live (adaptapi/simulated/fake), and the
    // real HUD backing-display geometry — together they answer the question
    // this screen used to leave silent: "am I looking at demo data, an
    // injected simulation, or a real car — and which display?" (Task 1).
    final sourceAsync = ref.watch(signalSourceProvider);
    final hudGeom = ref.watch(hudGeometryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          // ---- Signal source + HUD display (Task 1) --------------------------
          _SectionCard(
            title: l10n.diagSectionSource,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.sm,
                  Insets.lg,
                  Insets.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      l10n.diagSignalSource,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    sourceAsync.when(
                      data: (kind) => Chip(
                        key: const ValueKey('diag-signal-source-chip'),
                        label: Text(_signalSourceLabel(kind, l10n)),
                        visualDensity: VisualDensity.compact,
                      ),
                      loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => Chip(
                        label: Text(l10n.diagSignalSourceUnknown),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              _SignalRow(
                label: l10n.diagHudDisplay,
                value: hudGeom == null
                    ? '—'
                    : 'id=${hudGeom.displayId ?? '?'} '
                          '${hudGeom.w}×${hudGeom.h} @${hudGeom.dpi} dpi',
                unit: '',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- Motion -------------------------------------------------------
          _SectionCard(
            title: l10n.diagSectionMotion,
            children: <Widget>[
              _SignalRow(
                label: l10n.diagSpeed,
                value: speed?.toString() ?? '—',
                unit: 'km/h',
              ),
              _SignalRow(
                label: l10n.diagPowerFlow,
                value: _powerFlowLabel(powerFlow, l10n),
                unit: '',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- Lighting -----------------------------------------------------
          _SectionCard(
            title: l10n.diagSectionLighting,
            children: <Widget>[
              _SignalRow(
                label: l10n.diagBlinker,
                value: _blinkerLabel(blinker, l10n),
                unit: '',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- Energy -------------------------------------------------------
          _SectionCard(
            title: l10n.diagSectionEnergy,
            children: <Widget>[
              _SignalRow(
                label: l10n.diagCharging,
                value: charging ? l10n.diagYes : l10n.diagNo,
                unit: '',
              ),
              _SignalRow(
                label: l10n.diagChargePower,
                // Show signed kW whenever snapshot has it (charge or discharge).
                // Do not gate on charging==true — that raced the stream and
                // showed "—" while raw still had ±kW (0068).
                value: chargeKw != null
                    ? chargeKw.toStringAsFixed(1)
                    : '—',
                unit: 'kW',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- Battery ------------------------------------------------------
          _SectionCard(
            title: l10n.diagSectionBattery,
            children: <Widget>[
              _SignalRow(
                label: l10n.diagBatteryLevel,
                value: batteryPct?.toString() ?? '—',
                unit: '%',
              ),
              _SignalRow(
                label: l10n.diagBatteryTemp,
                value: batteryTempC?.toStringAsFixed(1) ?? '—',
                unit: '°C',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- USB mode (read-only) —————————————————————————————————————
          // Write-capable controls moved to the dedicated USB/ADB hub tile
          // (nav-usb → UsbAdbScreen — QA2-2).  Diagnostics is read-only.
          _SectionCard(
            title: l10n.usbAdbTitle,
            children: <Widget>[
              _SignalRow(
                label: l10n.usbCurrentMode,
                value: _usbModeLabel(usbPort.currentMode, l10n),
                unit: '',
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // ---- Raw snapshot (debug) -----------------------------------------
          // Collapsible dump of CarSnapshot JSON fields — handy on-car without
          // a debugger; not shown by default.
          _RawSnapshotTile(
            speed: speed,
            blinker: blinker,
            charging: charging,
            chargeKw: chargeKw,
            batteryPct: batteryPct,
            batteryTempC: batteryTempC,
            powerFlow: powerFlow,
            l10n: l10n,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Value-formatting helpers — convert enums to localized display strings.
  // ---------------------------------------------------------------------------
}

// ---------------------------------------------------------------------------
// Value-formatting helpers (file-scope so both widget and tests can use them).
// ---------------------------------------------------------------------------

String _blinkerLabel(BlinkerState state, AppLocalizations l10n) {
  return switch (state) {
    BlinkerState.off => l10n.diagBlinkerOff,
    BlinkerState.left => l10n.diagBlinkerLeft,
    BlinkerState.right => l10n.diagBlinkerRight,
    BlinkerState.hazard => l10n.diagBlinkerHazard,
  };
}

String _powerFlowLabel(PowerFlow flow, AppLocalizations l10n) {
  return switch (flow) {
    PowerFlow.unknown => l10n.diagPowerFlowUnknown,
    PowerFlow.drive => l10n.diagPowerFlowDrive,
    PowerFlow.regen => l10n.diagPowerFlowRegen,
    PowerFlow.standstill => l10n.diagPowerFlowStandstill,
  };
}

String _usbModeLabel(UsbMode mode, AppLocalizations l10n) => switch (mode) {
  UsbMode.peripheral => l10n.usbModePeripheral,
  UsbMode.host => l10n.usbModeHost,
  UsbMode.auto => l10n.usbModeAuto,
};

/// Localized label for the live [CarSignals.sourceKind] value ('adaptapi' |
/// 'simulated' | 'fake'); anything else (future values, decode hiccups) falls
/// back to the same "unknown" label a channel error would show.
String _signalSourceLabel(String kind, AppLocalizations l10n) => switch (kind) {
  'adaptapi' => l10n.diagSignalSourceAdaptApi,
  'simulated' => l10n.diagSignalSourceSimulated,
  'fake' => l10n.diagSignalSourceFake,
  _ => l10n.diagSignalSourceUnknown,
};

// ---------------------------------------------------------------------------
// _SectionCard — groups related signal rows under a header.
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.sm,
              ),
              child: Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SignalRow — one label / value / unit row.
// ---------------------------------------------------------------------------

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        unit.isEmpty ? value : '$value $unit',
        style: theme.textTheme.titleSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RawSnapshotTile — collapsible debug dump.
// ---------------------------------------------------------------------------

class _RawSnapshotTile extends StatelessWidget {
  const _RawSnapshotTile({
    required this.speed,
    required this.blinker,
    required this.charging,
    required this.chargeKw,
    required this.batteryPct,
    required this.batteryTempC,
    required this.powerFlow,
    required this.l10n,
  });

  final int? speed;
  final BlinkerState blinker;
  final bool charging;
  final double? chargeKw;
  final int? batteryPct;
  final double? batteryTempC;
  final PowerFlow powerFlow;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Format as readable key: value lines, one per field.
    final lines = <String>[
      'speedKmh: ${speed ?? 'null'}',
      'blinker: ${blinker.name}',
      'charging: $charging',
      'chargeKw: ${chargeKw ?? 'null'}',
      'batteryPct: ${batteryPct ?? 'null'}',
      'batteryTempC: ${batteryTempC ?? 'null'}',
      'powerFlow: ${powerFlow.name}',
    ];
    return Card(
      child: Theme(
        // The card already groups this row; suppress the ExpansionTile's own
        // top/bottom divider lines for a cleaner expand.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(l10n.diagRawSnapshot, style: theme.textTheme.titleSmall),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                0,
                Insets.lg,
                Insets.md,
              ),
              child: SelectableText(
                lines.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
