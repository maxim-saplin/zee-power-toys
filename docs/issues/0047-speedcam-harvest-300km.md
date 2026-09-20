---
status: implemented
labels: [hud, speedcam, osm, harvest]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0037]
modules: [SpeedcamPackStore, DHU UI]
tier: T1
owner: zee-dev
---

# 0047 — Harvest OSM cams within ~300 km (no region lock)

## Block scope
Replace country/BY pack harvest with **~300 km around host pose**.

Maxim HARD:
1. **No region lock / no BY mention** in Speedcam UI — drop Region·BY row
2. Harvest OSM cams within ~300 km of host pose (not country packs)
3. Map preview (0046) shows the resulting cache
4. Meta = **count / age / radius honesty** (e.g. within 300 km), not region ISO
5. Harvest **MUST keep other downloads — no purge**. New 300 km request **merges**
   into the on-device cam cache by cam id; do **not** wipe cams outside the new
   circle or older harvests.

## Definition of Done
- [x] Overpass `around:300000,lat,lon` (not BY bbox)
- [x] Merge-by-id into existing cache (upsert; retain outside-circle cams)
- [x] UI: no Region·BY row; coverage meta = within 300 km + count + age
- [x] Default center when no host pose: last harvest center, else Minsk
- [x] Unit tests: merge retains outside-circle cams; around QL used
- [ ] Runtime T1 map + harvest-without-BY (QA)

## Out of scope
- Multi-region selectors
- GPS wiring (host pose remains inject / drive / demo until later)
