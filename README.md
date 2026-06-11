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
— T1 Desktop (Linux/macOS), T2 Emulator, T3 Car (ADR 0004) — block by block (ADR 0007).

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

```bash
flutter run -d linux            # brings up DHU + HUD windows (two engines)
# drive it headlessly:
ZEE_VM_URI=<vm-service-uri> uv run dev/zee_drive.py whoami-all
```

## Status

Foundation Wave 0 in progress — **walking skeleton (Block 0001) is runtime-confirmed on T1**
(cross-isolate `gesture → ConfigStore → relay → HUD pixels`, driven + read through the
Feedback Loop). See [`docs/issues/BACKLOG.md`](docs/issues/BACKLOG.md) for the live board.
