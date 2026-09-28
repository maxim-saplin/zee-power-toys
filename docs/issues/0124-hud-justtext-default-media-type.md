---
status: accepted
tip: 94e3970
accepted: 2026-09-28
labels: [hud, battery, defaults, media]
created: 2026-09-28
satisfies: HUD-on battery Just text default + larger media artist—song
tier: T2
owner: zee-dev
blocked-by: []
modules: [BatteryConfig, BatteryWidget, MediaChrome]
priority: soon
filed-by: zee-pdm
related: [0120, 0123, 0056]
---

# 0124 — HUD Just text default + larger media title

## Product (Maxim 2026-09-28)

1. **Battery look default = Just text** (`BatteryLook.justText` / textOnly) — percent only, **no pack icon**. Overrides 0120 `batteryText` default. Pack looks remain user-selectable in HUD Settings.
2. Keep from 0120: **showTemp** + **rightBottom** + **charging grow-up** (stats stack above %; bottom edge stays put).
3. **Enlarge** B·compact `artist — song` type on windshield vs tip `6ba9c36` (`base*0.42` → `base*0.55`).

Live hold **1.1.0+28** — no version bump, no release.

## DoD (dens320 QA)

- [x] New / reset HUD-on: **Just text** — `%` only, **no** pack icon.
- [x] showTemp + rightBottom still on; charging kW stacks **above** % (grow-up).
- [x] Media artist — song visibly **larger** than post-`6ba9c36` B·compact.
- [x] Pack looks (Battery / Battery+text / Battery with bars) still choosable.
- [x] Tip to `origin/main`. Live still **1.1.0+28**.


## ACCEPT (PDM 2026-09-28)

**PDM ACCEPT 2026-09-28:** dens320 own-check PASS — after clear, HUD-on default Just text (**72% + 24°C**, no pack); charging grow-up **bottom_delta=0** / top_delta=**−26**; media Artist—Song glyph h **14 vs 11** on `6ba9c36` (~1.27×); pack looks still switchable. Soft FakeMediaOnly; existing prefs keep prior look.

| Stamp | Value |
|-------|-------|
| PDM ACCEPT tip | `94e3970` |
| docs stamp | *(this commit)* |
| Evidence | `tmp/qa/hud-bat-just-text-94e3970/FINDINGS.md` |
| HOST_SOT | Phys **2560×1600@320** · Override dens **160** · overlay **1024×576@213** |
| Live Toys | **1.1.0+28** hold (no bump) |

## Who-next

@zee-dev-beta four-point soft. Live stays **+28** unless Maxim GOs bump.

## Soft / out of scope

- Native MediaSession bind (still soft from 0123).
- Existing saved prefs keep prior look (only new/reset land on justText).

## DEV tip (2026-09-28 Europe/Minsk)

**Tip SHA:** `94e3970`

- `BatteryConfig` default `look=justText` / `contentMode=textOnly` / `style=outline`; fromJson empty-key fallbacks aligned.
- `_MediaChrome` artist—song `fontSize` `base*0.42` → `base*0.55`; `maxWidth` `4.0` → `5.2`.
- Tests: battery defaults / charging stack / media chrome font assert; geometry untouched.
- Live hold **1.1.0+28** (no bump).
- Who-next: **@zee-qa** dens320 cut.
