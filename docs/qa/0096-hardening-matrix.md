# Speedcam hardening matrix (T2) — draft for 0096

**Why:** 0092 mute is pin-proved; Maxim wants exhaustive T2 coverage so OSM / YNavi / dedupe / aging / enrich keep flowing and lane mute does not kill real speedcams.

**Rules:** harness only (0094) — `set-config` / `dump-state` / `speedcam-demo` / pose+snapshot / inject. No OCR. Keepalive on. Evidence under `tmp/qa/0096-cut-<sha>/` per case id.

## Axes (combinatorials — run every row; mark PASS/FAIL/SKIP)

### A. Sources & merge
| ID | Setup | Expect |
|----|--------|--------|
| A1 | OSM only (ynaviEnrich=false, inject none) | danger from OSM SPEED when posed; no ynavi:* ids |
| A2 | YNavi pure SPEED (no LANE), enrich/alert on, alertLaneCams=OFF | danger = that cam (must NOT mute) |
| A3 | YNavi pure LANE (+ optional SPEED flag), alertLaneCams=OFF | cam in pack; danger null |
| A4 | Same as A3, alertLaneCams=ON | danger = lane cam |
| A5 | OSM SPEED geo-match YNavi LANE → osm+ynavi | camType stamps LANE; mute OFF → no danger; ON → danger |
| A6 | OSM SPEED geo-match YNavi pure SPEED → osm+ynavi | stays SPEED (no false LANE); mute OFF → still alerts |
| A7 | YNavi collect=OFF | no new ynavi ingest / counter stable |
| A8 | YNavi alert=OFF (enrich may stay on) | pack may enrich; alert path ignores YNavi-sourced danger |

### B. Dedupe
| ID | Setup | Expect |
|----|--------|--------|
| B1 | Same eventId inject twice (ghost then route or reverse) | one alert / one id in sent set |
| B2 | New eventId same lat/lon | second event accepted (not false-deduped by geo alone) |
| B3 | Ghost+route shared sent-id (0072 path) | no double HUD fire |

### C. Aging / freshness
| ID | Setup | Expect |
|----|--------|--------|
| C1 | Cam older than aging slider threshold | dropped or non-alerting per 0073 DoD |
| C2 | Cam inside threshold | still alerts |
| C3 | Pack freshness / TTL (if live poller) | no ghost after kill window |

### D. Alert modes (non-lane SPEED fixture)
| ID | Setup | Expect |
|----|--------|--------|
| D1 | hudMode=any, sound dangerous | HUD+sound on approach |
| D2 | hudMode off / presence-only variants per 0060 | matches mode matrix (reuse prior recipes) |
| D3 | alertLaneCams OFF with mixed pack (OSM SPEED + YNavi LANE) | only SPEED in danger |

### E. Pose / range
| ID | Setup | Expect |
|----|--------|--------|
| E1 | Approach ~150–200 m heading toward cam | insideApproach + distanceM sane |
| E2 | Past cam / wrong heading | no false danger (facing rules) |
| E3 | Demo on → danger; demo off → null | harness speedcam-demo path |

### F. Regression pins
| ID | Setup | Expect |
|----|--------|--------|
| F1 | 53.907996,27.424118 lane mute OFF/ON/OFF | 0092 reaffirm |
| F2 | Maxim field coords (when supplied) | no false 60; true SPEED still fires |

## Unit gate (before / with T2)
- `flutter test test/services/speedcam_*` green, esp. `0088_lane_cam`, `ynavi_enrich`, `ynavi_merge`, `0072_74`, pack freshness / aging.

## DoD (proposal)
- [ ] Matrix checked into tip (`docs/qa/` or issue 0096)
- [ ] Every A/B/C/D/E row PASS or explicit SKIP+reason on T2
- [ ] F1 PASS; F2 if Maxim gives coords
- [ ] Beta four-point; PDM ACCEPT
- [ ] Soft: Script or zee_run recipe to replay matrix without OCR

## Owners (proposal)
- **zee-pdm:** file issue 0096, lock DoD / skip policy
- **zee-dev:** tip matrix doc + any harness gaps (inject pure SPEED vs LANE fixtures)
- **zee-qa:** drive T2 matrix cut, FINDINGS per row
- **zee-dev-beta:** early review matrix + four-point after FINDINGS; parallel cut on A2/A6 (true SPEED must flow)

## Harness gaps / fixtures (zee-dev notes, tip draft)

**Already good (0094):** `dump-state --surface dhu|hud` (`speedcamConfig`), `set-config` aliases (`ynaviEnrich` / `ynaviAlert` / `alertLaneCams`), `speedcam-demo on|off`, `zee_run keepalive --tier t2`, pose via `ext.zee.speedcam action=pose`.

**Fixture landed (0096 tip):**
```bash
uv run dev/feedback_loop.py --tier t2 speedcam-fixture \
  --source ynavi --cam-type SPEED --lat 53.907996 --lon 27.424118 \
  --event-id a2 --approach-m 200
# B dedupe: same --event-id with --no-clear
uv run dev/feedback_loop.py --tier t2 speedcam-fixture \
  --source ynavi --cam-type SPEED --lat 53.9 --lon 27.4 \
  --event-id dup --no-clear
# clear: ext.zee.speedcam action=fixtureClear
```
Unit gate: `test/services/speedcam_0096_fixture_test.dart` (A2/A3/A4/A5/A6/B1).

**Still soft gaps:**
- Aging C rows — set-config / packInstall aged timestamps; SKIP+reason if knobs absent.
- Demo path still fine for E3; prefer fixture for A/B.
