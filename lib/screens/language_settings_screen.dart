import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/config.dart';
import '../providers/services.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_layout.dart';

/// Language & appearance settings — clearly separated sections:
///
///   0. Appearance     — ConfigStore.themeMode ('auto' / 'dark' / 'light');
///      Auto follows system; Dark/Light are manual overrides. Live-reloads
///      DHU MaterialApp via appThemeModeProvider (HUD isolate unchanged).
///
///   1. App language   — sets ConfigStore.locale (null=system / 'en' / 'ru').
///      Reuses the existing Block 0011 behaviour (immediate live-reload of the
///      DHU MaterialApp locale via appLocaleProvider).
///
///   2. System language — sets the Android system language via SystemConfig.
///      On T2 (emulator) and T1 fake-unsupported mode the controls are disabled
///      with a localized "Available on the car only" hint.
///
///   3. Cluster language — sets the instrument-cluster HMI language via AdaptAPI
///      (SETTING_FUNC_LOCAL_CHANGED 0x20318a00 / IOtaSession.setSystemHMILanguage).
///      On T2 (emulator) controls are disabled with the same car-only hint.
///
/// Each system/cluster picker shows the last operation outcome below the
/// selected option (ok / error message).
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  // Last result strings — shown below the picker; null until first tap.
  String? _systemResult;
  String? _clusterResult;
  String? _ynaviResult;

  // Async cluster-supported / system-supported flags; null = loading.
  bool? _clusterSupported;
  bool? _systemSupported;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  // Loads both capability probes. They are deliberately separate methods on
  // SystemConfig (Task 3) — today both just check for the ecarx AdaptAPI
  // class, but they answer two distinct UI questions (is the System picker
  // enabled vs. the Cluster picker), so a future firmware could plausibly
  // expose one without the other.
  Future<void> _loadCapabilities() async {
    final cfg = ref.read(systemConfigProvider);
    final results = await Future.wait(<Future<bool>>[
      cfg.clusterSupported(),
      cfg.systemSupported(),
    ]);
    if (mounted) {
      setState(() {
        _clusterSupported = results[0];
        _systemSupported = results[1];
      });
    }
  }

  // ── App language helpers ──────────────────────────────────────────────────

  void _setAppLocale(String? code) {
    final store = ref.read(configStoreProvider);
    store.setConfig(store.value.copyWith(locale: code));
  }

  void _setThemeMode(String mode) {
    final store = ref.read(configStoreProvider);
    store.setConfig(store.value.copyWith(themeMode: mode));
  }

  // ── System language helpers ──────────────────────────────────────────────

  Future<void> _setSystemLanguage(Locale locale) async {
    final cfg = ref.read(systemConfigProvider);
    final result = await cfg.setSystemLanguage(locale);
    if (mounted) {
      setState(() {
        _systemResult = result.ok
            ? null // clear previous error on success
            : result.reason;
      });
    }
  }

  // ── Cluster language helpers ─────────────────────────────────────────────

  Future<void> _setClusterLanguage(Locale locale) async {
    final cfg = ref.read(systemConfigProvider);
    final result = await cfg.setClusterLanguage(locale);
    if (mounted) {
      setState(() {
        _clusterResult = result.ok ? null : result.reason;
      });
    }
  }

  // ── Boot remediations (T3 manual taps) ───────────────────────────────────

  Future<void> _restartYNavi() async {
    setState(() => _ynaviResult = 'Restarting…');
    try {
      const ch = MethodChannel('zee/boot');
      final map = await ch.invokeMapMethod<String, Object?>('restartYNavi');
      final ok = map?['ok'] == true;
      if (mounted) {
        setState(() => _ynaviResult = ok ? 'YNavi force-stopped' : 'Restart failed');
      }
    } catch (e) {
      if (mounted) setState(() => _ynaviResult = 'Error: $e');
    }
  }

  Future<void> _pushClusterLocaleEnglish() async {
    setState(() => _ynaviResult = 'Pushing locale…');
    try {
      const ch = MethodChannel('zee/boot');
      final map =
          await ch.invokeMapMethod<String, Object?>('pushClusterLocaleEnglish');
      final ok = map?['ok'] == true;
      if (mounted) {
        setState(
          () => _ynaviResult = ok ? 'Cluster locale → English' : 'Locale push failed',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _ynaviResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Watch config live so theme segment + locale radios reflect store.
    final cfg = ref.watch(appConfigProvider).when(
      data: (c) => c,
      loading: () => ref.read(configStoreProvider).value,
      error: (e, st) => ref.read(configStoreProvider).value,
    );
    final appLocale = cfg.locale;
    final themeMode = switch (cfg.themeMode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'auto',
    };

    // System locale — read directly from SystemConfig (not stored in ConfigStore).
    final systemLocale = ref.read(systemConfigProvider).systemLocale;

    final clusterSupported = _clusterSupported; // null = loading

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          // ──────────────────────────────────────────────────────────────
          // Section 0 — Appearance (DHU Auto / Dark / Light)
          // ──────────────────────────────────────────────────────────────
          SettingsSection(
            title: l10n.themeSectionTitle,
            padded: false,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.md,
                  Insets.lg,
                  Insets.md,
                ),
                child: SegmentedButton<String>(
                  key: const ValueKey('theme-mode-segmented'),
                  segments: <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'auto',
                      label: Text(l10n.themeAuto),
                      icon: const Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment<String>(
                      value: 'dark',
                      label: Text(l10n.themeDark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment<String>(
                      value: 'light',
                      label: Text(l10n.themeLight),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                  ],
                  selected: <String>{themeMode},
                  onSelectionChanged: (Set<String> next) {
                    if (next.isEmpty) return;
                    _setThemeMode(next.first);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ──────────────────────────────────────────────────────────────
          // Section 1 — App language
          // ──────────────────────────────────────────────────────────────
          SettingsSection(
            title: l10n.langSectionApp,
            padded: false,
            children: <Widget>[
              _LanguagePicker(
                selectedTag: appLocale,
                onChanged: _setAppLocale,
                enabled: true,
                keys: const _PickerKeys(
                  system: 'lang-system',
                  en: 'lang-en',
                  ru: 'lang-ru',
                ),
              ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ──────────────────────────────────────────────────────────────
          // Section 2 — System language
          // ──────────────────────────────────────────────────────────────
          SettingsSection(
            title: l10n.langSectionSystem,
            padded: false,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.md,
                  Insets.lg,
                  0,
                ),
                child: Text(
                  '${l10n.langCurrentValue}: ${systemLocale.toLanguageTag()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_systemSupported != true)
                // Show hint while loading and when we know system writes are
                // unsupported (Task 3: gated on the dedicated systemSupported()
                // capability probe — is the ecarx AdaptAPI present — not on the
                // ungrantable CHANGE_CONFIGURATION permission a prior version
                // checked instead).
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.xs,
                    Insets.lg,
                    0,
                  ),
                  child: Text(
                    l10n.langCarOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              // F5: when unsupported, omit radios entirely — a disabled group
              // with English pre-selected reads as a fake choice on T1.
              if (_systemSupported == true)
                _LanguagePicker(
                  selectedTag: systemLocale.languageCode,
                  onChanged: (tag) {
                    if (tag != null) _setSystemLanguage(Locale(tag));
                  },
                  enabled: true,
                  keys: const _PickerKeys(
                    system: 'sys-lang-system',
                    en: 'sys-lang-en',
                    ru: 'sys-lang-ru',
                  ),
                  showSystemOption: false,
                ),
              if (_systemResult != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.lg,
                    Insets.sm,
                  ),
                  child: Text(
                    _systemResult!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ──────────────────────────────────────────────────────────────
          // Section 3 — Cluster language
          // ──────────────────────────────────────────────────────────────
          SettingsSection(
            title: l10n.langSectionCluster,
            padded: false,
            children: <Widget>[
              if (clusterSupported == false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.md,
                    Insets.lg,
                    0,
                  ),
                  child: Text(
                    l10n.langCarOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                )
              else if (clusterSupported == null)
                const Padding(
                  padding: EdgeInsets.all(Insets.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              // F5: radios only when AdaptAPI is present — no empty/disabled
              // radio group that looks choosable on T1 desktop.
              if (clusterSupported == true)
                _LanguagePicker(
                  selectedTag: null, // cluster has no persistent local state
                  onChanged: (tag) {
                    if (tag != null) _setClusterLanguage(Locale(tag));
                  },
                  enabled: true,
                  keys: const _PickerKeys(
                    system: 'cluster-lang-system',
                    en: 'cluster-lang-en',
                    ru: 'cluster-lang-ru',
                  ),
                  showSystemOption: false,
                ),
              if (_clusterResult != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.lg,
                    Insets.sm,
                  ),
                  child: Text(
                    _clusterResult!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: Insets.xl),

          // ──────────────────────────────────────────────────────────────
          // Section 4 — Boot remediations (T3 manual)
          // ──────────────────────────────────────────────────────────────
          SettingsSection(
            title: 'Boot remediations',
            padded: false,
            children: <Widget>[
              ListTile(
                key: const ValueKey('btn-restart-ynavi'),
                title: const Text('Restart YNavi'),
                subtitle: Text(
                  _ynaviResult ?? 'Force-stop YNavi (phase0 silent restart)',
                ),
                trailing: const Icon(Icons.refresh),
                onTap: _restartYNavi,
              ),
              ListTile(
                key: const ValueKey('btn-push-cluster-en'),
                title: const Text('Push cluster locale → English'),
                subtitle: const Text('Same AdaptAPI write as boot remediation'),
                trailing: const Icon(Icons.language),
                onTap: _pushClusterLocaleEnglish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker widget — reusable radio group for EN / RU (/ system).
//
// [selectedTag] is a BCP-47 language code string ('en', 'ru') or null for
// "follow system".  [showSystemOption] controls whether the "System default"
// radio appears (used for App section; hidden for System/Cluster sections).
// [enabled] gates all radios — when false the group is visually muted and
// taps are ignored.
// ---------------------------------------------------------------------------

class _PickerKeys {
  const _PickerKeys({required this.system, required this.en, required this.ru});
  final String system;
  final String en;
  final String ru;
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({
    required this.selectedTag,
    required this.onChanged,
    required this.enabled,
    required this.keys,
    this.showSystemOption = true,
  });

  final String? selectedTag;
  final void Function(String?) onChanged;
  final bool enabled;
  final _PickerKeys keys;
  final bool showSystemOption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return RadioGroup<String?>(
      groupValue: selectedTag,
      // Wrap the callback: when disabled, all radio taps are ignored.
      // RadioGroup.onChanged is non-nullable (ValueChanged<T?>) so we
      // cannot pass null — instead we pass a no-op when the picker is locked.
      onChanged: enabled ? onChanged : (_) {},
      child: Column(
        children: <Widget>[
          if (showSystemOption)
            RadioListTile<String?>(
              key: ValueKey(keys.system),
              title: Text(l10n.languageSystem),
              value: null,
            ),
          RadioListTile<String?>(
            key: ValueKey(keys.en),
            title: Text(l10n.languageEnglish),
            value: 'en',
          ),
          RadioListTile<String?>(
            key: ValueKey(keys.ru),
            title: Text(l10n.languageRussian),
            value: 'ru',
          ),
        ],
      ),
    );
  }
}
