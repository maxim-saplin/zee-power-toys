---
status: done
labels: [app-shell, language]
created: 2026-06-11
satisfies: App-shell · System + Cluster language change
blocked-by: [0011]
modules: [SystemConfig]
tier: T2
---

# 0015 — System + Cluster language change

## Block scope
A localized DHU **Language** control to change the **system** language and the **Instrument-Cluster** language (distinct from the app's own EN/RU locale, Block 0011). The real writes are **privileged + car-specific (T3)**; this Block delivers the UI + the `SystemConfig` adapter wired to the best-available mechanism, attempts it on T2, and honestly defers the privileged Zeekr/cluster write to on-car with a clear path.

## Touches
- **Satisfies:** REQUIREMENTS — "Feature to change SYSTEM and Instrument Cluster language."
- **Modules:** SystemConfig (NativeSystemConfig on Android; FakeSystemConfig on T1).
- **ADRs:** 0002, 0003.

## Grounding — phase0 has the probes
- phase0 cluster/system locale mechanism: `/home/user/src/zee_hud_2/phase0-diagnostics/app/src/main/java/com/zeekr/phase0/probes/ClusterLocaleProbe.kt` + `SettingZeekrProbe.kt` + `SystemProbe.kt` — read these to learn how the cluster/system locale is read/written on the Zeekr (the Settings keys / AdaptAPI calls). Also `docs/knowledge/car-signals-adaptapi.md` for the AdaptAPI access pattern + `boot-fgs-apibrowser-diagnostics.md`.
- Current: `lib/services/system_config.dart` (the port: `systemLocale`, `setSystemLanguage`, `setClusterLanguage`), `lib/services/fakes/fake_system_config.dart`, `lib/screens/settings_home_screen.dart` (the existing Language section sets the *app* locale — keep that; add system+cluster here or a sub-screen).

## What to build
- **NativeSystemConfig** (Android, `lib/services/adapters/native_system_config.dart` + `zee/system_config` channel + Kotlin): `setSystemLanguage(Locale)` and `setClusterLanguage(Locale)` using the mechanism phase0's probes reveal (Settings write / AdaptAPI / Zeekr API). Guard everything — on the emulator (no Zeekr framework / no cluster) it returns a clear "unsupported on this device (T3)" result rather than crashing. `systemLocale` reads the current system locale. Inject on Android; T1 keeps FakeSystemConfig (in-memory).
- **Language screen** additions (`lib/screens/language_settings_screen.dart` or extend the existing Language section): clearly separate **App language** (the existing 0011 app-locale picker) from **System language** and **Cluster language** pickers (EN/RU + others phase0 supports). Selecting system/cluster calls the adapter; show the result/availability (disabled+explained when unsupported, like the YNavi gate).
- ARB keys (EN+RU). `ext.zee.*`: a path to attempt a system/cluster language set + read availability; readViewModel includes `{systemLocale, clusterSupported}`.

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] **T1:** Language screen shows App / System / Cluster sections, localized; App picker still works (0011); System/Cluster via the Fake reflect choices. — artifact: `shots/language.png` (RU: Язык приложения / Язык системы / Язык приборной панели).
- [x] **T2:** NativeSystemConfig invoked, no crash — `setLanguage scope=system value=ru` → `{ok:true}` (in-process `updateConfiguration`); `scope=cluster` → `{ok:false, reason:"unsupported-on-device"}` (AdaptAPI absent); `systemLocale` reads the real `en-US`. — artifact: logcat + readViewModel.
- [x] analyze clean; **173 tests** green; build linux+apk ok. Principles: honest about T3; no crash off-car; clear "Available on the car only" UX.

## Reconciliation
Built by Sonnet, runtime-verified by the orchestrator (Opus), 2026-06-11.
1. **Mechanism (ported from phase0 probes):**
   - **System language:** `ActivityManager.updateConfiguration(Locale)` — needs the `CHANGE_CONFIGURATION` signature permission for a persistent system-wide change (granted to Zeekr system APKs → **T3**). On the emulator it succeeds in-process (app-local, non-persistent) — surfaced honestly.
   - **Cluster language:** AdaptAPI `ICarFunction.setFunctionValue(0x20318a00=SETTING_FUNC_LOCAL_CHANGED, …)` or `IOtaSession.setSystemHMILanguage(langEnum)` (11=English_US, 30=Russian). Requires the `com.ecarx.xui.adaptapi` framework → **T3 only**; guarded `Car.create` → clean `unsupported-on-device` on the emulator.
   - **System locale read:** `resources.configuration.locales[0].toLanguageTag()` — works everywhere.
2. **App locale (0011) kept fully separate** (`ConfigStore.locale → appLocaleProvider → MaterialApp.locale`), unchanged.
3. **T3-only:** persistent system-wide language write (signature perm) + the cluster HMI write (AdaptAPI). Both code-complete + guarded; validated on-car.
