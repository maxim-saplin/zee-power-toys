# Knowledge: phase0 / zee-power-toys A/B testing with YNavi

How to run the older phase0 diagnostics bundle and our app on the **same emulator
(or the same on-car unit)** to compare map rendering before and after — without
the two hosts conflicting over the shared YNavi CarApp session.

---

## Why only one host may run at a time

Both apps (package `com.zeekr.phase0` and `com.zeepowertoys.zee_power_toys`) bind
to the SAME modded YNavi service
(`ru.yandex.yandexnavi/.projected.platformkit.presentation.service.NavigationCarAppService`)
as a CarApp host.  YNavi accepts exactly **one active CarApp session**; the second
`bindService` call receives the binder but the `onAppCreate` handshake is rejected
or the session is in an inconsistent state.  The result is a frozen map or a
`MessageTemplate` paywall loop rather than the cluster surface.

Additionally, `pm clear ru.yandex.yandexnavi` is required between switches: it
resets YNavi's session state and permission grants, preventing the stale session
from blocking the new host's `onAppCreate`.

---

## The reset sequence (T2 emulator and T3 on-car)

Run this **every time you switch from one host to the other**:

```bash
# 1. Stop the current host app.
#    Replace <PACKAGE> with the app you are stopping:
#      com.zeepowertoys.zee_power_toys  (our app)
#      com.zeekr.phase0                 (phase0)
adb -s emulator-5554 shell am force-stop <PACKAGE>

# 2. Clear YNavi state (session + data/cache; the APK stays installed).
adb -s emulator-5554 shell pm clear ru.yandex.yandexnavi

# 3. Re-grant location permissions (pm clear removes all runtime grants).
adb -s emulator-5554 shell pm grant ru.yandex.yandexnavi \
    android.permission.ACCESS_FINE_LOCATION
adb -s emulator-5554 shell pm grant ru.yandex.yandexnavi \
    android.permission.ACCESS_COARSE_LOCATION

# 4. Start the other host (see "Starting each host" below).
```

On T3 (physical Zeekr), replace `-s emulator-5554` with `-s <CAR_SERIAL>`.

---

## Starting each host

### Our app (zee-power-toys)

```bash
# Build + install (if not already installed)
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk

# Start via zee_run (waits for both surfaces to be up)
cd /home/user/src/zee-power-toys
uv run dev/zee_run.py up --tier t2

# Then enable the minimap via the Feedback Loop
uv run dev/feedback_loop.py set-config --surface dhu hudBoxOn=true minimapEnabled=true
uv run dev/feedback_loop.py minimap on=true x=0 y=0 w=640 h=360
```

### phase0 diagnostics (com.zeekr.phase0)

```bash
# Install (APK already built in the repo)
adb -s emulator-5554 install -r \
    /home/user/src/zee_hud_2/phase0-diagnostics/app/build/outputs/apk/debug/app-debug.apk

# IMPORTANT: Launch the activity first (Android 14 blocks FGS start from background receivers)
adb -s emulator-5554 shell am start -n com.zeekr.phase0/.MainActivity

# Wait ~3 s, then send the start broadcast
sleep 3
adb -s emulator-5554 shell am broadcast \
    -a com.zeekr.phase0.CARAPP_HOST \
    -n com.zeekr.phase0/.carapp.CarAppHostReceiver \
    --es action start

# Phase0 uses its own HUD virtual display. The map appears as a floating
# overlay window (top-left corner of the emulator screen).
# The "Navigation minimap" toggle inside phase0's HUD tab also starts the minimap.
```

> **Android 14 note:** phase0's `CarAppHostReceiver` starts a ForegroundService,
> which Android 14 disallows from a background broadcast receiver.  Launching the
> activity (`am start -n ...MainActivity`) first brings the app to the foreground
> and allows the subsequent broadcast to start the FGS.

---

## Capturing comparable screenshots

Both apps render their HUD via a virtual display overlay (`TYPE_APPLICATION_OVERLAY`
window containing a `VirtualDisplay`).  The overlay appears as a small window in
the **top-left corner** of the emulator framebuffer.

```bash
# Capture full framebuffer (2560×1600 on emulator-5554)
adb -s emulator-5554 exec-out screencap -p > /tmp/fb.png

# Crop the HUD overlay region (~310×185 px at top-left) and enlarge for inspection
python3 - <<'EOF'
from PIL import Image
img = Image.open('/tmp/fb.png')
hud = img.crop((0, 0, 310, 185))
hud.resize((620, 370)).save('/tmp/hud_crop.png')
EOF
```

Save the crop to `shots/redo/` for archival.  Use the same crop coordinates for
both apps so the comparison is at the same scale.

---

## Reference screenshots (Block 0021)

| Shot | Path | Description |
|------|------|-------------|
| **Our app (fixed)** | `shots/redo/t2-ynavi-map.png` | Block 0021: neon green-yellow roads, pure-black bg, labels readable |
| **phase0 reference** | `shots/redo/t2-ynavi-map-phase0-reference.png` | White-preset filtered Moscow map — natural night-mode yellow roads |

The key visual difference: our app uses the **green-yellow tint preset** (hueAngle=120)
so all map features are shifted toward neon green-yellow.  Phase0 defaults to the
**White preset** (hueAngle=290) which preserves YNavi's natural night-mode colors
(amber/yellow roads, white labels) with contrast boost + threshold.  Both are
readable; the green-yellow look is our brand HUD aesthetic.

---

## Why this matters for T3 on-car validation

On the physical Zeekr S2, the HUD is a real combiner display (`displayId=2`,
1024×576, 213 dpi).  The virtual-display overlay that is used on the emulator
does not exist; the `Presentation` renders directly onto the optical display.
Filter readability on-car depends on the projector's color response and ambient
light — parameters that cannot be fully simulated on the emulator.

The A/B protocol above lets you:
1. Validate phase0's filter (already on-car tested) as a known-good baseline.
2. Swap to our app and visually compare at the same camera/viewing angle.
3. Tune filter parameters via ADB without rebuilding:

```bash
# Live filter adjust via ADB broadcast (our app)
adb shell am broadcast \
    -n com.zeepowertoys.zee_power_toys/.carsignals.SimulateReceiver \
    -a com.zeepowertoys.SIMULATE \
    --es kind blinker --es value off   # keep session alive
# (future: zee/minimap setMinimapParam for filter params — see Block 0021 backlog note)
```

Reconcile any on-car parameter differences back into `createHudFilterPaint()`
defaults in `MainActivity.kt` and close with a commit before T3 sign-off.
