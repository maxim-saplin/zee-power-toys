---
status: done
labels: [app-shell, diagnostics]
created: 2026-06-11
satisfies: App-shell · Diagnostics dashboard (clean up the phase0 AP browser) + dashboard of system values
blocked-by: [0005, 0011]
modules: [CarSignals, FeedbackLoop]
tier: T1
---

# 0012 — Diagnostics dashboard

## Block scope
A clean, localized DHU **Diagnostics** screen showing **live car-signal values** (speed, blinker, charge V/A/kW, battery %/temp, power-flow) plus a **raw native dump** view (T2: the AdaptAPI/simulator snapshot). A focused replacement for phase0's AP browser — show the values that matter, no bloat. Live-updates from the CarSignals stream.

## Touches
- **Satisfies:** REQUIREMENTS — "Dashboard to display system values (e.g. battery temp)"; "Cleanup and update the phase0 AP browser."
- **Modules:** CarSignals (consume), FeedbackLoop (native dump on T2).
- **ADRs:** 0003 (derive from events), 0006.

## Grounding
- phase0 AP browser model (catalog/reader/pinning) to distill — NOT copy wholesale: [`docs/knowledge/boot-fgs-apibrowser-diagnostics.md`](../knowledge/boot-fgs-apibrowser-diagnostics.md).
- Live providers: `lib/providers/car_signals.dart` (speed/blinker/charge/battery/powerFlow). Native dump (T2): the `com.zeepowertoys.DUMP` broadcast / native snapshot. CarSnapshot in `lib/services/car_signals.dart`.
- Nav + l10n: `lib/screens/settings_home_screen.dart` (the Diagnostics placeholder to replace), `lib/l10n/*.arb`.

## What to build
- `lib/screens/diagnostics_screen.dart` — a live dashboard: rows/cards for each signal (label + current value + unit), updating from the providers (`ref.watch`). Group: Motion (speed, power-flow), Lighting (blinker), Energy (charge V/A/kW, charging state), Battery (%, temp). Emissive-neutral Material (this is the DHU touchscreen, normal Material — not the HUD). Clean, scannable, no clutter.
- Wire it into the settings hub Diagnostics section (replace the placeholder).
- ARB keys for the diagnostics labels (EN + RU).
- (Optional, if cheap) a "raw" expandable showing the full `CarSnapshot` JSON / native dump for debugging.
- `ext.zee.*`: the diagnostics view derives from the same providers the loop already drives via inject — so no new ext needed; just ensure readViewModel covers the values shown.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] Diagnostics shows live signal values; `inject` speed/blinker/charge/battery updates it live. — artifact: [`shots/diagnostics.png`](../../shots/diagnostics.png) (Speed 88, Blinker right, 37 kW, 64% / 29°C).
- [x] Localized (EN + RU). — artifact: `shots/diagnostics-ru.png` (Диагностика / Движение / …).
- [x] analyze clean; **114 tests** green (8 new: injected events surface; null → "—"); no regression. Principles: focused (4 grouped sections + collapsible raw), live, no phase0 bloat.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus) on T1, 2026-06-11.
1. **`powerFlowProvider` added** to `lib/providers/car_signals.dart` (was missing; the dashboard needs it).
2. **`dhuShotKey` RepaintBoundary hoisted** above `MaterialApp` (was wrapping only `home`) so `ext.zee.shot` captures pushed routes (e.g. DiagnosticsScreen), not just the hub. Correct placement for whole-surface DHU screenshots.
3. `nav-diagnostics` `ValueKey` added to the hub row so the loop can tap-navigate.
