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

  /// Diagnostics: Signal source section heading
  ///
  /// In en, this message translates to:
  /// **'Signal source'**
  String get diagSectionSource;

  /// Diagnostics: signal source row label
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get diagSignalSource;

  /// Signal source: native AdaptAPI (real car signals)
  ///
  /// In en, this message translates to:
  /// **'AdaptAPI (car)'**
  String get diagSignalSourceAdaptApi;

  /// Signal source: native simulator fallback, no AdaptAPI
  ///
  /// In en, this message translates to:
  /// **'Simulated (emulator)'**
  String get diagSignalSourceSimulated;

  /// Signal source: T1 pure-Dart fake
  ///
  /// In en, this message translates to:
  /// **'Fake (desktop)'**
  String get diagSignalSourceFake;

  /// Signal source: not yet resolved or a decode error
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get diagSignalSourceUnknown;

  /// Diagnostics: HUD backing-display geometry row label
  ///
  /// In en, this message translates to:
  /// **'HUD display'**
  String get diagHudDisplay;

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

  /// Language screen: App language section heading
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get langSectionApp;

  /// Language screen: System language section heading
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get langSectionSystem;

  /// Language screen: Instrument-cluster language section heading
  ///
  /// In en, this message translates to:
  /// **'Cluster language'**
  String get langSectionCluster;

  /// Hint shown when system/cluster write is T3-only (unsupported on emulator)
  ///
  /// In en, this message translates to:
  /// **'Available on the car only'**
  String get langCarOnly;

  /// Prefix label for the current system locale readout
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get langCurrentValue;

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

  /// Battery content mode label
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get batteryContentMode;

  /// Battery content: icon + percentage
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get batteryContentBoth;

  /// Battery content: icon only
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get batteryContentIconOnly;

  /// Battery content: percentage text only
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get batteryContentTextOnly;

  /// Battery pack style label
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get batteryStyle;

  /// Battery style: Steam Deck outline
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get batteryStyleOutline;

  /// Battery style: segmented blocks
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get batteryStyleFilled;

  /// Battery style: percentage inside pack
  ///
  /// In en, this message translates to:
  /// **'% inside'**
  String get batteryStylePctInside;

  /// Battery size slider label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get batterySize;

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
  /// **'YNavi minimap, size, colour look'**
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

  /// Minimap manual size slider label
  ///
  /// In en, this message translates to:
  /// **'Size (fraction of safe area)'**
  String get minimapSize;

  /// Minimap Look section heading (colour preset, brightness, contrast)
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get minimapLookSection;

  /// Minimap colour preset selector label
  ///
  /// In en, this message translates to:
  /// **'Colour preset'**
  String get minimapLookPreset;

  /// Phase0 White look bundle (hue pass keeps yellow cursor)
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get minimapLookPresetDefault;

  /// Minimap colour preset: green-yellow
  ///
  /// In en, this message translates to:
  /// **'Green-yellow'**
  String get minimapLookPresetGreenYellow;

  /// Minimap colour preset: white
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get minimapLookPresetWhite;

  /// Minimap colour preset: amber
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get minimapLookPresetAmber;

  /// Minimap colour preset: cyan
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get minimapLookPresetCyan;

  /// Minimap brightness slider label (backed by the native threshold param)
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get minimapLookBrightness;

  /// Minimap contrast slider label
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get minimapLookContrast;

  /// USB/ADB settings section label
  ///
  /// In en, this message translates to:
  /// **'USB / ADB'**
  String get sectionUsbAdb;

  /// USB/ADB section subtitle
  ///
  /// In en, this message translates to:
  /// **'USB host/peripheral mode'**
  String get sectionUsbAdbSubtitle;

  /// USB/ADB screen app-bar title (also used as section heading)
  ///
  /// In en, this message translates to:
  /// **'USB / ADB'**
  String get usbAdbTitle;

  /// USB mode: peripheral (ADB target, DHU is the USB device)
  ///
  /// In en, this message translates to:
  /// **'Peripheral'**
  String get usbModePeripheral;

  /// USB mode: host (DHU is the USB host)
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get usbModeHost;

  /// USB mode: auto (peripheral restored on every boot)
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get usbModeAuto;

  /// Prefix label for current USB mode readout
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get usbCurrentMode;

  /// Honest hint: this build lacks platform signing on any tier, so USB mode writes never take effect even though the selection is saved
  ///
  /// In en, this message translates to:
  /// **'Actually changing the USB mode requires platform (system) signing, which this build does not have — on the emulator or the car. Your selection is saved, but the USB role itself will not change until the app is platform-signed.'**
  String get usbPlatformSigningRequired;

  /// Accessibility label for the HUD minimap slot's schematic glyph (a11y only — no visible on-screen text)
  ///
  /// In en, this message translates to:
  /// **'MINIMAP'**
  String get hudSlotMinimap;

  /// HUD settings screen: toggle between the Safe-Area letterbox preview (default) and the full backing-display debug view
  ///
  /// In en, this message translates to:
  /// **'Full display'**
  String get hudFullDisplayToggle;

  /// Subtitle explaining the full-display debug toggle
  ///
  /// In en, this message translates to:
  /// **'Show the whole backing display, with the Safe Area outlined (debug)'**
  String get hudFullDisplayToggleSubtitle;

  /// HudPreview mode badge: Config Preview with forced demo CarSignal state
  ///
  /// In en, this message translates to:
  /// **'PREVIEW · DEMO'**
  String get hudPreviewBadgeDemo;

  /// HudPreview mode badge: Simulate screen's live preview driven by the real (unforced) CarSignal chain
  ///
  /// In en, this message translates to:
  /// **'LIVE · SIMULATED'**
  String get hudPreviewBadgeLive;

  /// Caption shown below the preset row when advanced mode overrides it
  ///
  /// In en, this message translates to:
  /// **'Custom dimensions active'**
  String get minimapPresetDisabledHint;

  /// Simulate nav tile title (debug-only screen)
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get sectionSimulate;

  /// Simulate nav tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Fire live signals to test the HUD'**
  String get sectionSimulateSubtitle;

  /// Simulate screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get simulateTitle;

  /// Explanatory caption at the top of the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Debug only — injects live CarSignals so you can watch the HUD react in real time.'**
  String get simulateDescription;

  /// Blinker control group label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Blinker'**
  String get simulateBlinkerLabel;

  /// Simulate blinker: off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get simulateOff;

  /// Simulate blinker: left
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get simulateLeft;

  /// Simulate blinker: right
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get simulateRight;

  /// Simulate blinker: hazard (both sides)
  ///
  /// In en, this message translates to:
  /// **'Hazard'**
  String get simulateHazard;

  /// Charging toggle label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get simulateChargingLabel;

  /// Charging kW slider label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Charge power'**
  String get simulateChargeKwLabel;

  /// Battery percent slider label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get simulateBatteryLabel;

  /// Battery temperature slider label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Battery temperature'**
  String get simulateBatteryTempLabel;

  /// Speed slider label on the Simulate screen
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get simulateSpeedLabel;

  /// DHU home app-bar title
  ///
  /// In en, this message translates to:
  /// **'Zee Power Toys'**
  String get homeTitle;

  /// Welcome column heading
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeWelcomeTitle;

  /// Short product intro on the home welcome column
  ///
  /// In en, this message translates to:
  /// **'HUD overlays and minimap for Zeekr. Check companion apps below, then open a section.'**
  String get homeWelcomeBody;

  /// Companion APK status section heading
  ///
  /// In en, this message translates to:
  /// **'Companion apps'**
  String get homeCompanionsTitle;

  /// Sections column heading
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get homeSectionsTitle;

  /// Companion APK status: installed
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get homeStatusInstalled;

  /// Companion APK status: missing
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get homeStatusMissing;

  /// Companion APK status: unknown (desktop / probe failed)
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get homeStatusUnknown;

  /// Install companion APK button on home
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get homeInstallAction;

  /// Phase0 minimapScale — lower shows more map in the square
  ///
  /// In en, this message translates to:
  /// **'Map density'**
  String get minimapContentScale;

  /// Hint under map density slider
  ///
  /// In en, this message translates to:
  /// **'Lower = more map area (phase0 default 0.5)'**
  String get minimapContentScaleHint;
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
