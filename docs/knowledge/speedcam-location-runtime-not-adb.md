# Speedcam location: runtime permission, not ADB theater

**When:** 2026-09-20 T3 (Gomel). **Issue:** [0050](../issues/0050-speedcam-car-location.md).

## What went wrong (product)

1. We wired YNavi `startLocationUpdates` and assumed pose would flow. On car, **`IAppHost.sendLocation` often never fires** without an active nav route — so “YNavi location” looked wired but delivered nothing.
2. Android GPS fallback existed in tip, but **runtime location permission was never requested** in UI. Manifest declared FINE/COARSE; fresh install → GPS silent no-op.
3. Harvest then reused a **prior Demo/Minsk center** — looked like “location works” after lab `adb pm grant`, which is **theater**: product path still broken for a normal user.
4. AdaptAPI has **no** lat/lon — cannot substitute for GPS.

## What “done” means now

| Path | Product | Lab only |
|------|---------|----------|
| In-app runtime allow dialog (or Settings) | **Required** | — |
| Harvest / HUD pose centered on live GPS | **Required** | — |
| Honest UI when denied (no silent Minsk) | **Required** | — |
| `adb pm grant …ACCESS_*_LOCATION` | — | OK for agents |
| Assuming YNavi `sendLocation` alone | **Insufficient** | — |

## Process learning (how we execute)

- **Do not ACCEPT “location works” on ADB grant.** Cut allow/deny with **no** `pm grant` on the product path (T3 allow; deny on T2 if platform-signed can’t revoke).
- **Do not treat “API started” as “data flows.”** Prove EventChannel emits with real lat/lon (`source=android_gps` or `ynavi`).
- **No silent geographic defaults** for harvest when live pose is missing — fail honest.
- README **UI ↔ CLI** table must list location as runtime (see README Install section). Keep that table updated when privileges change.

## Where this is recorded

- Product/tech: `docs/issues/0050-speedcam-car-location.md` (FAIL notes + DoD HARD + verify steps)
- User-facing: `README.md` → UI vs CLI / Location rows
- This file: process + anti-theater checklist for agents
