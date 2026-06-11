import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale.dart';
import '../screens/settings_home_screen.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey dhuShotKey = GlobalKey();

/// DHU surface app — localized (EN/RU), starts at the Settings hub.
class DhuApp extends ConsumerWidget {
  const DhuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);

    // The RepaintBoundary wraps the entire MaterialApp so that ext.zee.shot
    // captures whatever route is currently visible (Settings hub, pushed screens,
    // etc.) rather than just the static home widget.
    return RepaintBoundary(
      key: dhuShotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
      ),
    );
  }
}
