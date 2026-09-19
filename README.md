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

T1 is **desktop** — `dev/zee_run.py up` runs `flutter run -d linux` on Linux, or `-d macos` on
Darwin (requires the `macos/` runner + `desktop_multi_window` window-created callback). T1 uses
`FakeMinimapHost`, so it structurally cannot verify the Minimap on any host — use T2 for that.

```bash
uv run dev/zee_run.py up        # Linux host only — brings up DHU + HUD (two engines), waits until drivable
# then drive it headlessly (see the drive-zee-app skill):
uv run dev/feedback_loop.py whoami-all
```


## Credits

**Speedcam** locations come from [OpenStreetMap](https://www.openstreetmap.org/)
(© OpenStreetMap contributors), available under the
[Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/).

## Status

**Feature board through Speedcam** — Blocks 0001–0026 plus Speedcam
0029–0042 (pack → proximity → HUD/DHU radar → Demo → Alien fidelity) are
T1/T2 runtime-confirmed where QA cut them; Speedcam tip of record `956d6b8`; quality sweep HEAD may be newer (`f8a2118`+). `flutter analyze`
clean; run `flutter test` for the current count. **T3 (car) fidelity still
the source of truth** (ADR 0004) — do not treat T1/T2 alone as windshield-final.
See [`docs/issues/BACKLOG.md`](docs/issues/BACKLOG.md). Speedcam OSM credit: below.
