# Feedback Loop seed — `zee_drive.py`

Minimal client for the ADR 0004 **VM-service channel**. It talks to **one** Dart
VM service and reaches **every** Dart isolate of the two-engine multidisplay PoC
— the primary "DHU" isolate (`main()`) and the secondary "HUD" isolate
(`hudMain()`, spawned by `FlutterEngineGroup`) — calling the `ext.zee.*`
extensions registered in `../multidisplay_poc/lib/main.dart`.

This is the seed of the real driver: discovery + isolate resolution + a generic
`call`, mirroring the `nothingness` `drive.py` pattern but with zero dependency
on that project.

## Prerequisites

- A **debug** build of the PoC running on the emulator as **EXP 2** (two
  engines), so the VM service is enabled and both isolates exist:

  ```bash
  cd ../multidisplay_poc
  flutter build apk --debug --target-platform android-x64
  adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s emulator-5554 shell settings put global overlay_display_devices "1280x720/213"
  adb -s emulator-5554 shell am start -n com.zeepowertoys.multidisplay_poc/.MainActivity --ei exp 2
  # …reset the overlay when done:
  # adb -s emulator-5554 shell settings put global overlay_display_devices null
  ```

- Host tooling: `adb` on `PATH`, and either Python 3.10+ with the `websockets`
  package, or `uv` (the script carries a PEP 723 block, so `./zee_drive.py …`
  runs under `uv` with no setup).

## Usage

```bash
# List every isolate and the ext.zee.* RPCs each one registered.
./zee_drive.py isolates

# Call ext.zee.whoami on EVERY isolate and print a table (the decisive proof).
./zee_drive.py whoami-all

# Call an arbitrary ext.zee.* on a chosen isolate.
#   --isolate accepts: primary | hud | <isolateId> | <name>
./zee_drive.py call ext.zee.whoami --isolate hud
./zee_drive.py call ext.zee.bump   --isolate hud      # write probe (tick++)
```

`primary` / `hud` are resolved by calling `ext.zee.whoami` on each isolate and
matching the returned `surface` field — robust even when both isolates share the
VM name `main`.

## How VM-service discovery works

1. `adb logcat -d` is scanned for the line Flutter prints at boot:
   `The Dart VM Service is listening on http://127.0.0.1:<port>/<token>/`.
2. The `<port>` and `<token>` are parsed; `adb forward tcp:8181 tcp:<port>`
   exposes the device-local service on the host (token preserved for auth).
3. The client connects to `ws://127.0.0.1:8181/<token>/ws` and speaks JSON-RPC.

Overrides (skip discovery): `--vm-uri ws://…/ws` or `ZEE_VM_URI=…`. Other env
knobs: `ADB_SERIAL` (default `emulator-5554`), `ZEE_LOCAL_PORT` (default `8181`),
`ZEE_RPC_TIMEOUT` (seconds, default `30`).

## Exit codes

`0` success · `1` RPC error · `3` VM-service discovery failed.
