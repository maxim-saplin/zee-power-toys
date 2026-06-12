import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_layout.dart';

/// Combined Language Settings screen — three clearly separated sections:
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

  // Async cluster-supported flag; null = loading.
  bool? _clusterSupported;

  @override
  void initState() {
    super.initState();
    _loadClusterSupported();
  }

  Future<void> _loadClusterSupported() async {
    final cfg = ref.read(systemConfigProvider);
    final supported = await cfg.clusterSupported();
    if (mounted) {
      setState(() => _clusterSupported = supported);
    }
  }

  // ── App language helpers ──────────────────────────────────────────────────

  String? _currentAppLocale() {
    final store = ref.read(configStoreProvider);
    return store.value.locale;
  }

  void _setAppLocale(String? code) {
    final store = ref.read(configStoreProvider);
    store.setConfig(store.value.copyWith(locale: code));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Watch the app-locale live so the radio reflects config changes from
    // other screens (edge case: multiple settings screens open in tests).
    final appLocale = ref.watch(
      systemConfigProvider.select((_) => _currentAppLocale()),
    );

    // System locale — read directly from SystemConfig (not stored in ConfigStore).
    final systemLocale = ref.read(systemConfigProvider).systemLocale;

    final clusterSupported = _clusterSupported; // null = loading

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
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
              if (_clusterSupported == false ||
                  _clusterSupported == null && true)
                // Show hint when we already know system writes are unsupported
                // (_clusterSupported false ≡ no AdaptAPI ≡ no CHANGE_CONFIGURATION).
                // We key off clusterSupported as a proxy: if cluster is
                // unavailable (no ecarx framework), system writes are also
                // privileged + absent.
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
              _LanguagePicker(
                selectedTag: systemLocale.languageCode,
                onChanged: (tag) {
                  if (tag != null) _setSystemLanguage(Locale(tag));
                },
                // System write requires CHANGE_CONFIGURATION — T3 only.
                // Disable on emulator to make the constraint visible in the UI.
                enabled: _clusterSupported == true,
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
              _LanguagePicker(
                selectedTag: null, // cluster has no persistent local state
                onChanged: (tag) {
                  if (tag != null) _setClusterLanguage(Locale(tag));
                },
                enabled: clusterSupported == true,
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
