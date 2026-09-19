---
status: done  # 07f7389 / live 9d3b79f
labels: [hud, speedcam, osm]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: []
modules: [SpeedcamPackStore]
tier: T1
owner: zee-dev
---

# 0031 — OSM region pack download / cache / update

Parent: [0029](0029-speedcam-osm-epic.md).

## Block scope
`SpeedcamPackStore`: Overpass query for first pack **BY bbox** `(51.2,23.1)–(56.2,32.8)` — nodes `highway=speed_camera` (+ maxspeed/direction when present). Persist JSON under app cache with version/timestamp. Manual **Update** in DHU (no background spam). Validate + replace atomically.

## Definition of Done
- [x] Download → cache → load round-trip on T1 (network allowed) or recorded fixture if Overpass flaky
- [x] Fake/offline path if offline
- [x] DHU affordance: pack status + Update button (can live on Speedcam settings stub)
- [ ] Runtime-confirmed — artifact: pack file + cam count in dumpState

## Notes
Enforcement relations can land in a follow-up if nodes alone are enough for v1 radar.

## Fix tip (post-07f7389)
- macOS sandbox: `com.apple.security.network.client`
- Overpass: User-Agent + Accept (avoid HTTP 406)
- FL: `ext.zee.speedcam` action `packInstall` path=/body= for offline fixture
