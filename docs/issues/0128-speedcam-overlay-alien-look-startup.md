---
status: done
labels: [speedcam, overlay, startup]
created: 2026-10-02
satisfies: The system overlay uses the selected speedcam radar look on first render
blocked-by: []
modules: [SpeedcamOverlayApp, ConfigStore, zee/hub, SpeedcamSystemOverlayController]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-qa
related: [0070, 0106, 0116]
---

# 0128 — Alien selection sometimes renders Default in the system overlay

## Block scope

When Alien is selected, the DHU system overlay must render Alien on its first visible frame and after every overlay recreation. It must not remain on Default until another setting changes.

## Investigation

Reproduced twice on T2 (`Tablet_Android_12L`): with Alien persisted and the overlay off, `speedcam-demo on` created an overlay that painted the Default arrow/distance plate. The DHU and fresh `speedcamOverlay` isolate both reported `radarLook=alien`. A live Default → Alien config change on the existing engine changed the overlay pixels to Alien.

Likely cause: `speedcamOverlayMain()` starts `store.load()` without emitting the loaded config through `changes`, while `speedcamConfigProvider` falls back to the default during stream loading. Android can also deliver the initial `zee/hub` config before `overlayHub` exists; that envelope is dropped, with no config replay after engine creation. Relevant paths: [overlay entrypoint](../../lib/main.dart), [config provider](../../lib/providers/config.dart), [overlay app](../../lib/app/speedcam_overlay_app.dart), [Android relay](../../android/app/src/main/kotlin/com/zeepowertoys/zee_power_toys/MainActivity.kt), [overlay controller](../../android/app/src/main/kotlin/com/zeepowertoys/zee_power_toys/speedcam/SpeedcamSystemOverlayController.kt).

Evidence: [T2 native capture — Alien selected, Default rendered](../../tmp/qa/0128-investigation/alien-selected-default-render.png), 2560×1600. Overlay-isolate `dumpState` reported Alien on the same fresh enable.

## Definition of Done

- [x] A fresh overlay engine renders the persisted look on its first visible frame; repeated off/on cycles do not require a look toggle to converge.
- [x] Provider coverage verifies persisted config is available when the overlay mounts after load.
- [x] T2 native captures confirm Alien on first enable and after recreation; Default remains covered by the radar-look tests.

## Reconciliation

Root cause: `SpeedcamOverlayApp` mounted before asynchronous `store.load()` completed. Its provider read the default store value, and `load()` updates `value` without emitting a config event. The widget could therefore remain on Default until a later relay event.

Fix: keep the overlay relay listener armed first, then mount the overlay app only after the persisted config has loaded. This preserves the ConfigStore event contract and ensures the first provider read sees the selected look.

Verification: `test/providers/config_load_test.dart`; T2 fresh-enable and off/on recreation on the final build. Native captures: `tmp/qa/0128-live/final-build-first-alien.png` and `tmp/qa/0128-live/final-build-recreated-alien.png`. The overlay isolate reported `radarLook=alien` for both.