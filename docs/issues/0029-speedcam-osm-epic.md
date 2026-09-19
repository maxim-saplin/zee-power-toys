---
status: done  # product cut through 0042 @ 956d6b8; quality 0043 @ f8a2118
labels: [hud, speedcam, osm]
created: 2026-09-19
satisfies: HUD · Speedcam (REQUIREMENTS)
blocked-by: []
modules: [SpeedcamService, ConfigStore, HudHost]
tier: T1
---

# 0029 — Speedcam epic (OSM-only) — product cut

## Customer decision (2026-09-19 Maxim)
- **No YNavi integration** for speedcams (drop phase0 YNavi harvest / `SpeedCamDataReceiver` path).
- **OSM data only** — harvest, download, cache, update offline packs.
- **HUD:** radar-like UI (similar spirit to minimap) on the **right**; show **direction + distance**; alert when approaching (~**500 m**).
- **DHU:** larger radar view (zoom out), config.
- **Look:** Alien-locator / CRT green sweep (movie) as the radar look; alert sound ideally matching the game approach sting.

## Data (investigate → implement)
OSM has rich coverage via:
- Nodes `highway=speed_camera` (+ `maxspeed`, `direction`, …)
- Relations `type=enforcement` / `enforcement=maxspeed` (avg-speed sections)
- Overpass for regional queries; Geofabrik PBF + filter for large packs; third-party OSM-derived country dumps (e.g. SpeedCams.world CSV/GPX) as optional import format

**Design must define:** region pack selection, first download, incremental update, on-device cache layout, freshness, legal note (OSM ODbL; some locales restrict warning devices).

## Child Blocks (file next; one in-flight)
| ID | Slice | Tier |
|----|--------|------|
| 0030 | SpeedcamService port + Fake + FL inject | T1 |
| 0031 | OSM pack download / cache / update | T1 |
| 0032 | Proximity (500 m approach, bearing/distance) | T1 |
| 0033 | HUD right-side Alien/CRT radar + Preview | T1 |
| 0034 | DHU large radar + config | T1 |
| 0035 | Alert sound (approach sting) | T1/T2 |

Out of scope this epic: YNavi bridge, Alien as separate “bonus” after default — Alien **is** the default look.

## Definition of Done (epic)
T1: inject/seed → HUD radar shows direction/distance; pack pipeline downloads a region; approach <500 m alerts. T2: same with native GPS. T3: on-car fidelity later.
