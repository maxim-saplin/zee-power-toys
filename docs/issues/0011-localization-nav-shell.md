---
status: in-progress
labels: [app-shell, localization, l10n]
created: 2026-06-11
satisfies: Cross-cutting · Localization EN/RU (picks system lang, choosable in UI) + DHU navigation shell
blocked-by: [0006]
modules: [ConfigStore, app-shell, SystemConfig]
tier: T1
---

# 0011 — Localization (EN/RU) + DHU navigation shell

## Block scope
Make the DHU UI **localized (EN + RU)** — auto-picks the system locale, overridable in-app and persisted (ConfigStore) — and give the DHU a clean **navigation shell** (a Settings hub with sections: HUD, Diagnostics, Language, Install — the latter as routed placeholders that later Blocks fill). Retrofit the existing HUD-settings strings to l10n. Defaults excellent; the HUD surface itself is mostly icon/number content (minimal text to localize).

## Touches
- **Satisfies:** REQUIREMENTS — "Localized, EN and RU, picks system lang, allows to choose in the UI."
- **Modules:** ConfigStore (locale), the DHU app-shell navigation, SystemConfig (systemLocale).
- **ADRs:** 0006 (locale provider), 0003 (persisted choice).

## Grounding
- l10n setup (flutter gen-l10n, intl, flutter_localizations, delegates, supportedLocales, locale override via ConfigStore): [`docs/knowledge/flutter-conventions-riverpod-testing.md`](../knowledge/flutter-conventions-riverpod-testing.md) §5.
- Current: `lib/app/dhu_app.dart` (shows `HudSettingsScreen`), `lib/screens/hud_settings_screen.dart`, `lib/services/config_store.dart` (`AppConfig`), `lib/services/system_config.dart` (`SystemConfig.systemLocale`), `lib/providers/`.

## What to build
- pubspec: `flutter: generate: true`; add `flutter_localizations` (sdk) + `intl`. `l10n.yaml` (arb-dir `lib/l10n`, template `app_en.arb`, output `app_localizations.dart`). Ensure the generated localizations are available (not blocked by the `*.g.dart` ignore — gen-l10n output is `app_localizations*.dart`, fine; commit them or document regeneration).
- `lib/l10n/app_en.arb` + `app_ru.arb` — strings for the app shell + HUD settings (titles, section names, blinker/battery/safe-area labels, etc.). Keep keys tidy.
- `lib/providers/locale.dart`: `appLocaleProvider` — resolves to ConfigStore's stored locale override, else `SystemConfig.systemLocale`, else EN. Add `locale` (nullable = follow system) to `AppConfig` (plain JSON).
- `lib/main.dart` DHU MaterialApp: `localizationsDelegates` (AppLocalizations + Global*), `supportedLocales: [en, ru]`, `locale: ref.watch(appLocaleProvider)`.
- **Navigation shell**: `lib/screens/settings_home_screen.dart` — a Settings hub listing sections (HUD, Diagnostics [placeholder], Language [a working locale picker: System / English / Русский], Install [placeholder]); use `go_router` OR a simple `Navigator`/`IndexedStack` (justify; go_router only if it earns its place — REQUIREMENTS fights bloat). The HUD section opens the existing `HudSettingsScreen`. The Language section sets the locale override (persisted) → UI switches live.
- Retrofit `hud_settings_screen.dart` (and `dhu_app.dart`) user-facing strings to `AppLocalizations`.
- `ext.zee.*`: a way for the loop to read the active locale + drive a locale change (e.g. `setConfig locale=ru|en|system`); readViewModel includes `locale`.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md).
- [x] App starts in the system locale; the Language picker switches EN↔RU live and persists. — artifact: `shots/dhu-en.png`, `shots/dhu-ru.png` (same screen, different language).
- [x] Driving `setConfig locale=ru` switches the DHU UI to Russian; `locale=system` follows system. — artifact: before/after + readViewModel locale.
- [x] Navigation shell: sections reachable; HUD section opens HUD settings. — artifact: shot of the settings hub.
- [x] analyze clean; tests green (locale resolution: override > system > en; ARB has no missing keys); no regression. Principles: minimal nav, no bloat; defaults excellent (follow system).

## Reconciliation

**gen-l10n output dir:** `l10n.yaml` sets `output-dir: lib/l10n`; generated files land at `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart`. They are NOT `*.g.dart` so the existing `.gitignore` does not suppress them — `git status` shows them as `??` (untracked), confirming they will be committed.

**synthetic-package:** The Flutter 3.44.1 toolchain no longer supports the `synthetic-package` option (deprecated). It was removed from `l10n.yaml` after pub get warned; `output-dir` alone is sufficient to place generated files in `lib/l10n/`.

**intl version:** `intl: any` in pubspec.yaml resolved without conflict (flutter_localizations pins its own compatible version). Effective version visible in pubspec.lock.

**go_router:** NOT used. The DHU navigation tree is four sections deep at most — `Navigator.push`/`MaterialPageRoute` is sufficient and adds zero dependencies (REQUIREMENTS: no bloat). `go_router` was explicitly ruled out.

**RadioListTile API:** Flutter 3.44 deprecated `groupValue`/`onChanged` on `RadioListTile` in favour of a `RadioGroup` ancestor widget. The language picker uses `RadioGroup<String?>` with `RadioListTile` children — the modern API, zero deprecation warnings.

**AppConfig.copyWith locale sentinel:** A `const Object _unset` sentinel distinguishes `copyWith(locale: null)` (clear the override) from `copyWith()` (leave unchanged), because `null` is a valid value for `locale`.

**RU translations:** Natural, concise Russian. "Поворотники" for Blinker (the standard automotive term for turn signals), "Аккумулятор" for Battery, "Безопасная область" for Safe Area, "По умолчанию" for System default (idiomatic).

