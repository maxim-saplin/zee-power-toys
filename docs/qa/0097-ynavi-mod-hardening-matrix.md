# YNavi mod hardening matrix (T2) — 0097

**Why:** Same exhaustive bar as toys 0096, for Zee mods on Yandex Navi **v27 Live** and **v30 stretch**.

**Rules:** T2 Tablet/DHU-size emu. Evidence under `tmp/qa/0097-cut-<tag-or-sha>/` per case id (screenshots + adb notes + log snippets). No OCR fantasy. Honest SKIP+reason when the surface is missing or emu cannot prove; never ghost PASS from memory. Keepalive FGS often **PARTIAL on emu** — document, do not invent PASS.

**Install sources (GH Releases only):**
- v27: https://github.com/maxim-saplin/ynavi-zee/releases/tag/ynavi-zeekr-v27.0.2
- v30: https://github.com/maxim-saplin/ynavi-zee/releases/tag/ynavi-zeekr-v30
- Toys companion for C*: Live `1.1.0+18`

```bash
# example
adb -s emulator-5554 install -g -r -d deepal_v27.0.2.apk
adb -s emulator-5554 shell monkey -p ru.yandex.yandexnavi -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 logcat -d | egrep -i 'AndroidRuntime|FATAL EXCEPTION|passport|KeepAlive|SpeedCam|YNaviTraffic'
```

## Axes (run every applicable row; mark PASS / FAIL / SKIP)

### V. Version × variant install
| ID | Setup | Expect |
|----|--------|--------|
| V1 | Install v27 Deepal; cold open | launches; no crash loop; package stable |
| V2 | Install v27 Zeekr margined; cold open | same |
| V3 | Install v27 Zeekr OS7 nomargin; cold open | same |
| V4 | Install v30 stretch arm64; cold open | same (pre-release OK) |

### L. Letterbox geometry
| ID | Setup | Expect |
|----|--------|--------|
| L1 | V1 on screen | top/bottom bands; left ~0 |
| L2 | V2 on screen | left margin band (margined preset / ~480dip class) |
| L3 | V3 on screen | left ~0 (OS7) |
| L4 | Day↔night toggle on any V* | letterbox bg + chrome retheme with map (no stuck controls theme) |

### S. Scale / density
| ID | Setup | Expect |
|----|--------|--------|
| S1 | Shipped UI scale on V1–V4 | chrome usable; no density crash; not clipped into unusable |
| S2 | Map chrome vs map labels | map scale independent and readable |

### K. Keepalive
| ID | Setup | Expect |
|----|--------|--------|
| K1 | After open: services / ongoing notif per preset | Deepal≈audio; Zeekr≈fgs (+ UI keepalive as declared) |
| K2 | Background / recents survival smoke | survive or **PARTIAL/SKIP+reason on emu** — never fake PASS |

### B. Banners
| ID | Setup | Expect |
|----|--------|--------|
| B1 | Home + short guidance smoke | no ad banner surfaces |
| B2 | Same | no promo banner surfaces |

### C. Speedcam bridge → toys
| ID | Setup | Expect |
|----|--------|--------|
| C1 | Toys **1.1.0+18** + YNavi V2 or V4; **follow C1 recipe below** | toys pack / dump-state shows ynavi-sourced cams (or Intent observed) |
| C2 | YNavi alone (toys uninstalled) | bridge does not crash YNavi |

**C1 recipe (required — silent fail without this):**
1. Install toys Live **1.1.0+18** package `com.zeepowertoys.zee_power_toys` (Release APK). If `SHARED_USER_INCOMPATIBLE`, uninstall the prior toys build first — that trap is **toys debug↔release / sharedUser pairing**, not a YNavi install failure.
2. With toys up: set `ynaviEnrich=true` (default **OFF** drops `SPEEDCAM_DATA` / ynavi ingest). Prefer harness `set-config` / dump-state echo before drive.
3. Prove with **ghost+route** (or freeDriveRoute / ghost path), **not** windshield. Windshield alone is not a C1 PASS.
4. Expect: dump-state / pack shows `source=ynavi` (or Intent observe) while enrich is ON.

```bash
# sketch — adjust serial / zee_run as on station
adb -s emulator-5554 install -g -r -d zee-power-toys.apk   # Release 1.1.0+18
# if INSTALL_FAILED_SHARED_USER_INCOMPATIBLE: adb uninstall com.zeepowertoys.zee_power_toys && retry
# harness: set-config ynaviEnrich=true ; dump-state --surface dhu|hud | grep -i enrich
# drive: ghost+route (not windshield) until SPEEDCAM_DATA / ynavi cams appear
```

### T. Traffic recovery
| ID | Setup | Expect |
|----|--------|--------|
| T1 | Connectivity flip (airplane off→on) under map | traffic layer recovers without full relaunch — SKIP+reason OK if T2 cannot flip cleanly |

### P. Passport / account gate
| ID | Setup | Expect |
|----|--------|--------|
| P1 | Cold open V4 (and spot V2) | no hard Passport wall block for stretch bypass behavior; document actual gate |

### G. Guidance offsets (known debt)
| ID | Setup | Expect |
|----|--------|--------|
| G1 | Under guidance: next-turn + speed shields | letterbox shift per `ISSUE_WITH_GUIDANCE_OFFSETS` — expected FAIL or document; compare v27 vs v30; not HOLD unless v30 worse |

### R. Reinstall / switch
| ID | Setup | Expect |
|----|--------|--------|
| R1 | Uninstall → reinstall same variant | clean cold open |
| R2 | v27 ↔ v30 same package if versionCode allows | upgrade/downgrade story documented (or SKIP if signature/version blocks) |

## DoD / skip (locked — see `docs/issues/0097-ynavi-mod-hardening-matrix.md`)
- V1–V4 + applicable L/S/B; C1 or honest SKIP; K/T/P/G/R documented.
- Evidence tree; tip FINDINGS; beta early review on V4+C1; PDM ACCEPT.
- Soft: K2, T1, G1.

## Owners
- **zee-pdm:** issue / DoD / ACCEPT
- **zee-qa:** T2 matrix FINDINGS
- **zee-dev:** fixes on FAIL only
- **zee-dev-beta:** parallel V4 + C1 + early review
