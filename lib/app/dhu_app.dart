import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale.dart';
import '../providers/theme_mode.dart';
import '../screens/settings_home_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/dhu_scaled_layout.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey dhuShotKey = GlobalKey();

/// DHU surface app — localized (EN/RU), starts at the Settings hub.
///
/// Theme follows [appThemeModeProvider] (ConfigStore) without engine restart.
/// HUD isolate is a separate [HudApp] and stays dark/emissive.
class DhuApp extends ConsumerWidget {
  const DhuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dhuLight,
      darkTheme: AppTheme.dhu,
      themeMode: themeMode,
      // Scale-up + text-scale clamp applied together inside the MaterialApp
      // builder so descendants see the correct post-scale logical dimensions.
      //
      // DhuScaledLayout: for the DHU's 2560×1600 @ 160 dpi (dpr ≈ 1.0) display
      // the auto scale factor is 2.19, making the UI premium-large and crisp.
      // On smaller / normal-DPI screens (tests, desktop T1) scale ≈ 1.0 and
      // the widget is a transparent pass-through (no overhead).
      //
      // RepaintBoundary (key=dhuShotKey) is placed inside DhuScaledLayout so
      // ext.zee.shot captures the scaled content.
      //
      // MediaQuery.withClampedTextScaling: pin text scaling to 1.0 so OS
      // accessibility settings cannot re-inflate the hand-tuned type scale.
      builder: (context, child) => RepaintBoundary(
        key: dhuShotKey,
        child: DhuScaledLayout(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.0,
            child: child!,
          ),
        ),
      ),
      // Localization delegates — AppLocalizations + the three Flutter globals.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // null → follow the system locale (platform default).
      locale: locale,
      home: const SettingsHomeScreen(),
    );
  }
}
