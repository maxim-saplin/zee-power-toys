# TIP_A — 0122A minimap surface callback + live tiles

**When:** 2026-09-29 13:55 Europe/Minsk (UTC+3)  
**Cook:** zee-dev · both repos `main` · no Live Toys bump · no release upload  
**Before:** `tmp/qa/0122-abc-t2-repro/` A FAIL + car `tmp/qa/0122-minimap-car-t3/RCA.md` §A

## Tips / APKs

| Component | Value |
|---|---|
| ynavi-zee tip | `4b3bab9df6e956f3fe74867d31f53d0948ecf835` |
| YNavi APK | `/Users/admin/src/ynavi-zee/tmp/v30/builds/ynavi_30.8.1_zeekr_arm64_0122a_signed.apk` |
| YNavi sha256 | `864bc52fe8adb30504fa49f61a24c67b2d43ef7beeced015ffbd788b7bba3672` |
| YNavi version | 30.8.1 / 739652660 (unchanged; includes prior Tip B tree) |
| Toys code tip | `757db4de13c87cf73a067a253e9ffc5311bc7f82` |
| Toys debug APK | `/Users/admin/src/zee-power-toys/tmp/qa/0122a-tip-a/app-debug.apk` |
| Toys sha256 | `a4e426bc995fc2dcefae3da96d1d430cf136cb8fd51c4164eb57399f34018611` |
| Toys version | 1.1.0+30 (unchanged; DEBUG prove build only) |

## Named RCA / fix

YNavi v30 did not register `IAppHost.setSurfaceCallback`, so the host could not
dispatch `onSurfaceAvailable` and `MinimapView` received no map frames.

1. **YNavi P9 port:** v30 `srn0.d()` could emit `NotAvailable` and push
   `PLUS_COUNTRY_UNAVAILABLE` instead of creating the cluster Screen. It now
   always emits `HasPlus`, matching the durable v27 P9 behavior; the real
   cluster Screen registers the surface callback.
2. **Host race hardening:** a same-value `minimapScale=0.5` config replay used
   to force stop→start. Epoch-1 teardown then called `onAppPause/onAppStop`
   after epoch-2 had resumed. Toys now skips no-op geometry rebinds and checks
   supersession before pause and again after pause.
3. `MessageTemplate` / handshake alone are explicitly not the bug or tile
   acceptance. The governing proof is callback + map pixels.

## Files changed

### ynavi-zee
- `features/patches/0122a-srn0-p9-hasplus.smali`
- `docs/0122-v30-zee-parity.md`
- Build-tree application (ignored): `tmp/v30/src/smali_classes9/srn0.smali`

### zee-power-toys
- `android/app/src/main/kotlin/com/zeepowertoys/zee_power_toys/MainActivity.kt`
- `android/app/src/main/kotlin/com/zeepowertoys/zee_power_toys/carapp/YNaviCarAppHost.kt`

## dens320 prove — PASS

HOST_SOT: Tablet_Android_12L, physical 2560×1600@320, override dens160,
overlay **1024×576@213 displayId=2** (same role Toys targets).

Cold install/launch evidence in `tmp/qa/0122a-tip-a/`:

```text
onHandshakeCompleted SUCCESS
setMinimapParam(minimapScale): skip cold rebind — geometry unchanged scale=0.5
IAppHost.setSurfaceCallback callback=true
onSurfaceAvailable SUCCESS
INNER_TEMPLATE ... PlaceListNavigationTemplate
```

Native display-2 shot `shots/minimap-overlay-native.png` and governing crop
`shots/crop-bounds_150_191_210.png` show live map roads/buildings/labels,
Svislach River and yellow vehicle arrow. Crop stats: nonblack **0.430**,
colorful **0.358**, 1327 unique RGB values (previous FAIL overlay ≈0.001
nonblack / 0.000 colorful).

Car USB remains for later physical verification; the same host lifecycle and
P9 path are fixed. **C not cooked.**
