# T3 first run — install & fidelity prep

One-page runbook for the first on-car (DHU) pass of **zee-power-toys**.
Not product/ship. Complements [phase0-ynavi-ab-testing.md](./phase0-ynavi-ab-testing.md).

## Frozen tip

| | |
|--|--|
| Branch | `t1-harness` |
| SHA | `24de35e577af5f0c2931930aadff6a4f7237d362` (`24de35e`) |
| Package | `com.zeepowertoys.zee_power_toys` |
| Phase0 (disable first) | `com.zeekr.phase0` |
| YNavi | `ru.yandex.yandexnavi` |

Do **not** verify a moving tip. Re-freeze explicitly if the SHA changes.

## Prerequisites

- ADB to the DHU (`adb devices` shows the car serial). USB Peripheral may need zSupport / prior ADB enable — our in-app UsbMode write is **platform-signing gated**.
- APK built from the frozen tip with **AOSP/car platform signing** (`android/tools/zeekr/androiddebugkey.jks`, `useAospDebugKey=true`) — same key phase0 uses. Manifest has `sharedUserId=android.uid.system`.
- Verify signing before install: `apksigner verify --print-certs <apk>` should show the AOSP androiddebugkey / platform cert, **not** Flutter’s default debug cert.

```bash
cd /path/to/zee-power-toys
git checkout <TIP>   # see Frozen tip; after signing port, tip advances
# Ensure android/gradle.properties has useAospDebugKey=true
flutter build apk --debug    # or --release — both use aospDebug when the key is present
# APK: build/app/outputs/flutter-apk/app-debug.apk (or app-release.apk)
apksigner verify --print-certs build/app/outputs/flutter-apk/app-debug.apk
```

## 1. Prove phase0 is out of the way

```bash
CAR=<serial>   # adb devices

adb -s "$CAR" shell am force-stop com.zeekr.phase0
adb -s "$CAR" shell pm disable-user --user 0 com.zeekr.phase0

# Proof for QA:
adb -s "$CAR" shell pm list packages | grep -E 'phase0|zeepowertoys'
# Expect: com.zeekr.phase0 listed but disabled; no phase0 Presentation on HUD.
```

Re-enable later: `adb -s "$CAR" shell pm enable com.zeekr.phase0`

## 2. Reset YNavi (required when switching hosts)

Only **one** CarApp host may own YNavi at a time.

```bash
adb -s "$CAR" shell pm clear ru.yandex.yandexnavi
adb -s "$CAR" shell pm grant ru.yandex.yandexnavi android.permission.ACCESS_FINE_LOCATION
adb -s "$CAR" shell pm grant ru.yandex.yandexnavi android.permission.ACCESS_COARSE_LOCATION
```

## 3. Install our APK

```bash
adb -s "$CAR" install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s "$CAR" shell am start -n com.zeepowertoys.zee_power_toys/.MainActivity
```

Confirm package present: `pm list packages | grep zeepowertoys`

## 4. Feedback Loop (optional but preferred)

Use the car serial instead of `emulator-5554`. Drive via existing `dev/zee_drive.py` / `ext.zee.*` once VM URI / ADB forward is up (same dual-channel contract as T2). Capture `dumpState` + shots with `--layer both` for HUD truth; blink judgments need a burst, not one frame.

## 5. QA fidelity cut (pass/fail on pixels)

1. Idle HUD clean (no hollow `--%` chrome)
2. AdaptAPI blinker / charge / speed → live HUD ink
3. YNavi minimap on/off at Safe Area
4. Config Preview stays lit + battery looks sane on DHU
5. System language: **one try**, report honest result (no papering)

**Known gated (not blockers):** USB toggle + System language until platform-signed APK.  
**Not claimed:** GH polish, Speedcam, YNavi zoom/label scale.

## Roles

| Who | Owns |
|-----|------|
| zee-dev | Frozen tip, APK, this runbook, install + FL wiring |
| zee-qa | Fidelity pass/fail with shots + dumpState; requires phase0-disabled proof first |
| zee-pdm | Product gating for “T3 clear” vs known-gated |
