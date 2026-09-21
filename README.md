# Zee Power Toys

**[EN](README.md) | [RU](README_RU.md)**

**Windshield HUD + DHU utilities for Zeekr Android head units.**

Customization app for the car’s central display (DHU) and the windshield HUD:
navigation minimap, blinkers, speed-camera alerts, battery/charge looks, language
and companion installs — without fighting the stock UI.

| | |
|---|---|
| **This app** | [maxim-saplin/zee-power-toys](https://github.com/maxim-saplin/zee-power-toys) |
| **YNavi mod (HUD map)** | [maxim-saplin/ynavi-zee](https://github.com/maxim-saplin/ynavi-zee) |
| **Launcher mod** | [maxim-saplin/zeekr_apk_mod](https://github.com/maxim-saplin/zeekr_apk_mod) |

> Icons / store artwork: with Maxim (hand vectors). Screenshots below are
> placeholders until those land — don’t block install or tips on artwork.

---

## Quick start

### On the car (DHU)

1. Install a **platform-signed** release APK (`sharedUserId` / AOSP debug key).
2. Open **Zee Power Toys** → grant location when Speedcam asks.
3. Optional companions via **Install**: YNavi mod + Launcher mod (GitHub Releases).
4. Toggle HUD / Speedcam / Minimap in Settings. Self-update: **Install → Check for updates**.

```bash
flutter build apk --release -PuseAospDebugKey=true
adb install -g -r -d build/app/outputs/flutter-apk/app-release.apk
```

**Never `adb uninstall`** day-to-day — it wipes prefs. Prefer `install -r`.
See [0054](docs/issues/0054-settings-survive-reinstall.md).

### Self-update (GitHub Releases)

When a public Release exists for this repo:

- **Tag:** `1.0.0+N` (or `v1.0.0+N`) — `N` = build / versionCode  
- **Asset:** `zee-power-toys.apk` (fallback `app-release.apk`)  
- In-app: **Install → Check for updates → Update now**

CI: push a tag `1.0.0+N` (or `workflow_dispatch`) → `release.yml` uploads `zee-power-toys.apk`.

### Desktop bring-up (T1)

```bash
uv run dev/zee_run.py up    # Linux (or macOS with macos/ runner)
```

T1 uses fakes for minimap — use T2 emulator / T3 car for YNavi surface.

---

## What you get

- **HUD** — blinkers, battery/charge, Safe-Area layout, Config Preview  
- **Minimap** — YNavi on the windshield (needs YNavi mod; usually Launcher too)  
- **Speedcam** — OSM packs, approach alerts, Default/Alien looks, Demo on HUD  
  **Does not require YNavi** — packs alone are enough  
- **DHU** — language/cluster, Install companions, diagnostics, USB/ADB helpers  
- **Self-update** — public GitHub Releases → PackageInstaller  

---

## Screenshots

| DHU home | Speedcam | HUD preview |
|----------|----------|-------------|
| _placeholder — Maxim icons_ | _placeholder_ | _placeholder_ |

Drop PNGs under `docs/assets/` (e.g. `dhu-home.png`) and link them here when ready.

---

## Companion APKs

Optional for Speedcam; required for minimap / default-nav integration.

| Companion | Repo | Release |
|-----------|------|----------------|
| YNavi margined (default) | [ynavi-zee](https://github.com/maxim-saplin/ynavi-zee) | tag `ynavi-zeekr-v12` / `zeekr_v12_margined.apk` |
| YNavi OS7+ (no left margin) | same | same tag / `zeekr_v12_os7_nomargin.apk` |
| Zeekr Launcher mod | [zeekr_apk_mod](https://github.com/maxim-saplin/zeekr_apk_mod) | tag `launcher-670` / `XCLauncher3-670-yandex-signed.apk` |

**Install UI** downloads Release assets and runs `PackageInstaller`.  
**Location** is runtime (in-app dialog) — not install-time. `adb pm grant` is lab-only.

Prep notes: [docs/publish/0044-notes-for-maxim.md](docs/publish/0044-notes-for-maxim.md).

---

## Versioning

`pubspec.yaml`: **`MAJOR.MINOR.PATCH+BUILD`** (from `1.0.0+1`).  
Bump `+BUILD` on every tip/car APK; bump semver for user-facing releases.  
Keep `lib/app_version.dart` in sync. See [CHANGELOG.md](CHANGELOG.md).

---

## Credits

**Speedcam** locations from [OpenStreetMap](https://www.openstreetmap.org/)
(© OpenStreetMap contributors), [ODbL](https://opendatacommons.org/licenses/odbl/).

---

## For contributors / agents

Domain glossary: [`CONTEXT.md`](CONTEXT.md) · Requirements: [`REQUIREMENTS.md`](REQUIREMENTS.md) · ADRs: [`docs/adr/`](docs/adr/) · Blocks: [`docs/issues/`](docs/issues/).

### Architecture (last)

Flutter draws **all** designed UI on DHU + HUD as **two engines / two isolates**
(ADR 0001). Kotlin is a thin host (Presentation, AdaptAPI, YNavi, boot, overlays).
Services (`CarSignals`, `ConfigStore`, `MinimapHost`, …) are ports — Dart fakes
off-car, native adapters on-car (ADR 0002/0003), Riverpod injection (ADR 0006).
Verified via dual-channel Feedback Loop across T1 Desktop / T2 Emulator / T3 Car
(ADR 0004), block by block (ADR 0007).

| Path | What |
|------|------|
| `lib/` | Flutter app (same Dart brain every tier) |
| `dev/` | Feedback-Loop driver (`zee_drive.py`) — not imported by `lib/` |
| `android/`, `linux/` | Platform hosts |
| `docs/adr/` | Architecture Decision Records |
| `docs/issues/` | Block board |
| `docs/knowledge/` | Grounding from phase0 / PoCs / YNavi mod |
| `_poc/` | Throwaway topology PoCs |

```bash
uv run dev/feedback_loop.py whoami-all
```
