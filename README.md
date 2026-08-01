# Zee Power Toys

A customization and utility app for a Zeekr car's Android head unit (DHU). It controls
what is drawn on the windshield **HUD** — navigation minimap, blinkers, speed-camera
alerts, charging and battery info — and exposes car configuration (language, downloads,
diagnostics) through the central touchscreen.

See [`CONTEXT.md`](CONTEXT.md) for the domain glossary, [`REQUIREMENTS.md`](REQUIREMENTS.md)
for the *what*, and [`docs/adr/`](docs/adr/) for the load-bearing *how*.

## Architecture in one paragraph

Flutter renders 100% of the designed UI on both surfaces (DHU touchscreen + HUD), running
as **two engines / two isolates** (ADR 0001). Native Kotlin is a thin host (Presentation,
AdaptAPI, YNavi, boot). The system is a set of **services** (`CarSignals`, `ConfigStore`,
`MinimapHost`, `HudHost`, …) exposed as ports; per environment only the *host* swaps — Dart
fakes off-car, real native adapters on-car (ADR 0002/0003). Riverpod injects them (ADR 0006).
Everything is built and verified through a **dual-channel Feedback Loop** across three Tiers
— T1 Desktop (Linux-only), T2 Emulator, T3 Car (ADR 0004) — block by block (ADR 0007).

## Layout

| Path | What |
|------|------|
| `lib/` | The Flutter app (the Dart "brain", identical on every tier) |
| `dev/` | Out-of-tree Feedback-Loop driver (`zee_drive.py`) — never imported by `lib/` |
| `android/`, `linux/` | Platform hosts (native Kotlin / GTK runner) |
| `docs/adr/` | Architecture Decision Records |
| `docs/issues/` | The Block board — one runtime-confirmed slice at a time |
| `docs/knowledge/` | Grounding distilled from phase0 / the PoCs / the YNavi mod |
| `_poc/` | Throwaway PoCs that proved the topology (kept for reference) |

## Running (T1 Desktop)

T1 is **Linux-only** — `dev/zee_run.py:152` hardcodes `flutter run -d linux`, and there is no
`macos/` runner directory (only `linux/`), so this will not launch on a macOS host. On macOS,
use `flutter test` for the fast loop, and treat T2 (Android emulator) as the truth tier for
anything touching the native edge — T1 also runs against `FakeMinimapHost`, so it structurally
cannot verify the Minimap on any host.

```bash
uv run dev/zee_run.py up        # Linux host only — brings up DHU + HUD (two engines), waits until drivable
# then drive it headlessly (see the drive-zee-app skill):
uv run dev/feedback_loop.py whoami-all
```

## Status

**MVP feature-complete, T1/T2 runtime-confirmed** — 26 Blocks
([`docs/issues/0001`](docs/issues/0001-walking-skeleton.md)–[`0026`](docs/issues/0026-hud-preview-vs-live-simulate-split.md))
are runtime-confirmed on T1 and, where the native edge is involved, T2 (the Android emulator),
driven + read through the Feedback Loop; `flutter test` passes 261 tests. **The app has never
run on T3 (the real car)** — the tier ADR 0004 itself names as the source of truth for fidelity.
See [`docs/issues/BACKLOG.md`](docs/issues/BACKLOG.md) for the live board.
