import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Zee Power Toys'**
  String get appTitle;

  /// Settings hub screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// HUD settings section label
  ///
  /// In en, this message translates to:
  /// **'HUD'**
  String get sectionHud;

  /// HUD settings section subtitle
  ///
  /// In en, this message translates to:
  /// **'Blinker, battery, layout'**
  String get sectionHudSubtitle;

  /// Diagnostics section label
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get sectionDiagnostics;

  /// Diagnostics section subtitle
  ///
  /// In en, this message translates to:
  /// **'Live car-signal values'**
  String get sectionDiagnosticsSubtitle;

  /// Diagnostics screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// Diagnostics: Motion section heading
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get diagSectionMotion;

  /// Diagnostics: Lighting section heading
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get diagSectionLighting;

  /// Diagnostics: Energy section heading
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get diagSectionEnergy;

  /// Diagnostics: Battery section heading
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get diagSectionBattery;

  /// Diagnostics: speed row label
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get diagSpeed;

  /// Diagnostics: power-flow row label
  ///
  /// In en, this message translates to:
  /// **'Power flow'**
  String get diagPowerFlow;

  /// Power-flow state: unknown
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get diagPowerFlowUnknown;

  /// Power-flow state: drive
  ///
  /// In en, this message translates to:
  /// **'drive'**
  String get diagPowerFlowDrive;

  /// Power-flow state: regen
  ///
  /// In en, this message translates to:
  /// **'regen'**
  String get diagPowerFlowRegen;

  /// Power-flow state: standstill
  ///
  /// In en, this message translates to:
  /// **'standstill'**
  String get diagPowerFlowStandstill;

  /// Diagnostics: blinker row label
  ///
  /// In en, this message translates to:
  /// **'Blinker'**
  String get diagBlinker;

  /// Blinker state: off
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get diagBlinkerOff;

  /// Blinker state: left
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get diagBlinkerLeft;

  /// Blinker state: right
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get diagBlinkerRight;

  /// Blinker state: hazard
  ///
  /// In en, this message translates to:
  /// **'hazard'**
  String get diagBlinkerHazard;

  /// Diagnostics: charging state row label
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get diagCharging;

  /// Diagnostics: charging power (kW) row label
  ///
  /// In en, this message translates to:
  /// **'Charge power'**
  String get diagChargePower;

  /// Generic yes value
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get diagYes;

  /// Generic no value
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get diagNo;

  /// Diagnostics: battery level row label
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get diagBatteryLevel;

  /// Diagnostics: battery temperature row label
  ///
  /// In en, this message translates to:
  /// **'Battery temperature'**
  String get diagBatteryTemp;

  /// Diagnostics: raw snapshot expansion tile title
  ///
  /// In en, this message translates to:
  /// **'Raw snapshot'**
  String get diagRawSnapshot;

  /// Language settings section label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// Language section subtitle
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get sectionLanguageSubtitle;

  /// Install section label
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get sectionInstall;

  /// Install section subtitle
  ///
  /// In en, this message translates to:
  /// **'Modded Launcher & YNavi mod'**
  String get sectionInstallSubtitle;

  /// Install screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installTitle;

  /// Install target: modded launcher name
  ///
  /// In en, this message translates to:
  /// **'Modded Launcher'**
  String get installLauncherName;

  /// Install target: modded launcher description
  ///
  /// In en, this message translates to:
  /// **'Launcher with YNavi set as the default navigation app'**
  String get installLauncherDesc;

  /// Install target: YNavi mod name
  ///
  /// In en, this message translates to:
  /// **'YNavi mod (HUD)'**
  String get installYnaviName;

  /// Install target: YNavi mod description
  ///
  /// In en, this message translates to:
  /// **'Yandex.Navi mod with HUD support and minimap broadcast'**
  String get installYnaviDesc;

  /// Install button label (used for first install and updates)
  ///
  /// In en, this message translates to:
  /// **'Install / Update'**
  String get installButtonLabel;

  /// Install progress phase: downloading
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get installPhaseDownloading;

  /// Install progress phase: installing
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get installPhaseInstalling;

  /// Install progress phase: done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get installPhaseDone;

  /// Install progress phase: failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get installPhaseFailed;

  /// Language picker screen title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Option: follow the system locale
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// Option: English language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Option: Russian language
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// Placeholder text for unimplemented sections
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// HUD settings screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'HUD Settings'**
  String get hudSettingsTitle;

  /// Blinker section heading
  ///
  /// In en, this message translates to:
  /// **'Blinker'**
  String get blinkerSection;

  /// Blinker shape label
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get blinkerShape;

  /// Blinker shape: dots
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get blinkerShapeDots;

  /// Blinker shape: arrows
  ///
  /// In en, this message translates to:
  /// **'Arrows'**
  String get blinkerShapeArrows;

  /// Blinker shape: smiley
  ///
  /// In en, this message translates to:
  /// **'Smiley'**
  String get blinkerShapeSmiley;

  /// Blinker size slider label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get blinkerSize;

  /// Blinker vertical position slider label
  ///
  /// In en, this message translates to:
  /// **'Vertical position'**
  String get blinkerVerticalPosition;

  /// Blinker side-padding slider label
  ///
  /// In en, this message translates to:
  /// **'Side padding (from edge)'**
  String get blinkerSidePadding;

  /// Battery section heading
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get batterySection;

  /// Toggle: show battery indicator
  ///
  /// In en, this message translates to:
  /// **'Show battery indicator'**
  String get showBattery;

  /// Toggle: show battery temperature
  ///
  /// In en, this message translates to:
  /// **'Show temperature'**
  String get showTemp;

  /// Toggle: show charging stats panel
  ///
  /// In en, this message translates to:
  /// **'Show charging stats (while charging)'**
  String get showChargingStats;

  /// Safe Area readout heading
  ///
  /// In en, this message translates to:
  /// **'Safe Area (fractions)'**
  String get safeAreaSection;

  /// Safe Area inset slider label
  ///
  /// In en, this message translates to:
  /// **'Safe Area inset'**
  String get safeAreaInset;

  /// Debug toggle label for HUD bounding box
  ///
  /// In en, this message translates to:
  /// **'Debug HUD box'**
  String get debugHudBox;

  /// Slider start label: top
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get positionTop;

  /// Slider end label: bottom
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get positionBottom;

  /// Slider start label: edge
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get positionEdge;

  /// Minimap settings section label
  ///
  /// In en, this message translates to:
  /// **'Minimap'**
  String get sectionMinimap;

  /// Minimap settings section subtitle
  ///
  /// In en, this message translates to:
  /// **'YNavi minimap, presets, dark/light'**
  String get sectionMinimapSubtitle;

  /// Minimap settings screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'Minimap'**
  String get minimapTitle;

  /// Minimap section heading
  ///
  /// In en, this message translates to:
  /// **'Minimap'**
  String get minimapSection;

  /// Toggle: enable the YNavi minimap
  ///
  /// In en, this message translates to:
  /// **'Enable minimap'**
  String get minimapEnable;

  /// Hint shown when YNavi mod is absent
  ///
  /// In en, this message translates to:
  /// **'Install a compatible YNavi mod to enable the minimap'**
  String get minimapYnaviUnavailableHint;

  /// Minimap preset selector label
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get minimapPreset;

  /// Minimap preset: compact
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get minimapPresetCompact;

  /// Minimap preset: balanced
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get minimapPresetBalanced;

  /// Minimap preset: large
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get minimapPresetLarge;

  /// Minimap advanced expansion tile title
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get minimapAdvanced;

  /// Minimap manual width slider label
  ///
  /// In en, this message translates to:
  /// **'Width (fraction of safe area)'**
  String get minimapWidth;

  /// Minimap manual height slider label
  ///
  /// In en, this message translates to:
  /// **'Height (fraction of safe area)'**
  String get minimapHeight;

  /// Minimap theme section heading
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get minimapThemeSection;

  /// Minimap theme: follow system brightness
  ///
  /// In en, this message translates to:
  /// **'System (auto)'**
  String get minimapThemeAuto;

  /// Minimap theme: force dark palette
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get minimapThemeDark;

  /// Minimap theme: force light palette
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get minimapThemeLight;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
