---
status: tipped
labels: [install, race]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [InstallScreen, AppSelfUpdate, InstallerController, NativeInstaller]
tier: T2
tip: a07a549
---

# 0084 — Parallel toys Update + YNavi Install race

## Block scope
Car session 2026-09-22: starting toys self-update and YNavi install together aborted the toys update; after YNavi progress finished the app restarted as if toys (not YNavi) had installed.

## FINDINGS — root cause
Flutter `EventChannel` allows **one** active sink. Each `NativeInstaller.install()` opened its own `receiveBroadcastStream({url})`:

1. Second listen cancelled the first → Kotlin `onCancel` nulled `eventSink` **and** `inFlightKey`.
2. Toys Dart stream ended mid-flight → Update card looked aborted / wrongly “done”.
3. All further progress went to the YNavi sink (wrong card). Executor still ran toys first; PackageInstaller for toys restarted the process — matched “YNavi progress finished, then app restarted as toys”.

Not a shared PackageInstaller session id collision; not concurrent adb. Progress-stream overwrite + single in-flight key.

## Tip (`a07a549`)
- Kotlin: tag every progress event with `url`; track `inFlightUrls` set; `onCancel` only drops the sink (jobs keep running); pool of 3 for parallel downloads; **self-update commit waits** until companion installs leave flight so process death does not strand YNavi.
- Dart: one shared EventChannel subscription; fan-out by `url`; start only via MethodChannel.
- Tests: `test/services/native_installer_parallel_test.dart`.

## Definition of Done
- [x] Reproduce root cause from code (EventChannel steal) — tipped
- [x] Isolate installers so both complete correctly (multiplex + defer self-update commit)
- [ ] Runtime evidence on T2 (PDM QA)
- [ ] PDM ACCEPT after double-check

## QA recipe (T2)
1. Install screen: Check for Update so Update button is enabled (needs a newer GH release than the build under test, or sideload an older build).
2. Tap **Update** and immediately tap **Install** on YNavi (margined).
3. Expect: both progress bars advance independently; Update does **not** jump to done/failed when YNavi starts.
4. Expect: YNavi reaches Done first (or at least commits) while Update may show “installing” then the app restarts from the toys APK.
5. After restart: YNavi package present (`com.yandex.yandexnavi` / device package probe) and toys version matches the release just installed.
6. logcat `ZEE/Installer`: one EventChannel subscribe; two `startInstall` lines; self-update line `waiting for N companion` then `companions clear — committing`.
