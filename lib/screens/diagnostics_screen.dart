import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/car_signals.dart';
import '../services/car_signals.dart';

/// Live DHU diagnostics dashboard — shows current car-signal values grouped by
/// domain.  Updates via [ref.watch] on the CarSignals providers; no polling
/// needed because the providers react to the stream from FakeCarSignals (T1) or
/// NativeCarSignals (T2).
///
/// This screen replaces the placeholder in the Settings hub (Block 0012).
/// It is intentionally focused: show the values that matter, no AP-browser
/// bloat.  Raw snapshot dump is available via an optional ExpansionTile for
/// debugging sessions.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Read all live providers — each rebuilds only the widget that watches it;
    // wrapping the whole screen in a single ConsumerWidget is fine at this scale.
    final speed = ref.watch(speedProvider);
    final blinker = ref.watch(blinkerProvider);
    final charging = ref.watch(chargingProvider);
    final chargeKw = ref.watch(chargeKwProvider);
    final batteryPct = ref.watch(batteryPctProvider);
    final batteryTempC = ref.watch(batteryTempCProvider);
    final powerFlow = ref.watch(powerFlowProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
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
          const SizedBox(height: 8),

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
          const SizedBox(height: 8),

          // ---- Energy -------------------------------------------------------
          _SectionCard(
            title: l10n.diagSectionEnergy,
            children: <Widget>[
              _SignalRow(
                label: l10n.diagCharging,
                value: charging == null
                    ? '—'
                    : (charging ? l10n.diagYes : l10n.diagNo),
                unit: '',
              ),
              _SignalRow(
                label: l10n.diagChargePower,
                // Show kW only while charging; "—" otherwise so the row stays
                // visible but clearly empty when the car is not plugged in.
                value: (charging == true && chargeKw != null)
                    ? chargeKw.toStringAsFixed(1)
                    : '—',
                unit: 'kW',
              ),
            ],
          ),
          const SizedBox(height: 8),

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
          const SizedBox(height: 8),

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
}

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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
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
      title: Text(label),
      trailing: Text(
        unit.isEmpty ? value : '$value $unit',
        style: theme.textTheme.bodyLarge?.copyWith(
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
  final bool? charging;
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
      'charging: ${charging ?? 'null'}',
      'chargeKw: ${chargeKw ?? 'null'}',
      'batteryPct: ${batteryPct ?? 'null'}',
      'batteryTempC: ${batteryTempC ?? 'null'}',
      'powerFlow: ${powerFlow.name}',
    ];
    return Card(
      child: ExpansionTile(
        title: Text(
          l10n.diagRawSnapshot,
          style: theme.textTheme.labelLarge,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SelectableText(
              lines.join('\n'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
