// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zee Power Toys';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionHud => 'HUD';

  @override
  String get sectionHudSubtitle => 'Blinker, battery, layout';

  @override
  String get sectionDiagnostics => 'Diagnostics';

  @override
  String get sectionDiagnosticsSubtitle => 'Live car-signal values';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagSectionSource => 'Signal source';

  @override
  String get diagSignalSource => 'Source';

  @override
  String get diagSignalSourceAdaptApi => 'AdaptAPI (car)';

  @override
  String get diagSignalSourceSimulated => 'Simulated (emulator)';

  @override
  String get diagSignalSourceFake => 'Fake (desktop)';

  @override
  String get diagSignalSourceUnknown => 'Unknown';

  @override
  String get diagHudDisplay => 'HUD display';

  @override
  String get diagSectionMotion => 'Motion';

  @override
  String get diagSectionLighting => 'Lighting';

  @override
  String get diagSectionEnergy => 'Energy';

  @override
  String get diagSectionBattery => 'Battery';

  @override
  String get diagSpeed => 'Speed';

  @override
  String get diagPowerFlow => 'Power flow';

  @override
  String get diagPowerFlowUnknown => 'unknown';

  @override
  String get diagPowerFlowDrive => 'drive';

  @override
  String get diagPowerFlowRegen => 'regen';

  @override
  String get diagPowerFlowStandstill => 'standstill';

  @override
  String get diagBlinker => 'Blinker';

  @override
  String get diagBlinkerOff => 'off';

  @override
  String get diagBlinkerLeft => 'left';

  @override
  String get diagBlinkerRight => 'right';

  @override
  String get diagBlinkerHazard => 'hazard';

  @override
  String get diagCharging => 'Charging';

  @override
  String get diagChargePower => 'Charge power';

  @override
  String get diagYes => 'yes';

  @override
  String get diagNo => 'no';

  @override
  String get diagBatteryLevel => 'Battery level';

  @override
  String get diagBatteryTemp => 'Battery temperature';

  @override
  String get diagRawSnapshot => 'Raw snapshot';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionLanguageSubtitle => 'App display language';

  @override
  String get sectionInstall => 'Install';

  @override
  String get sectionInstallSubtitle => 'Modded Launcher & YNavi mod';

  @override
  String get installTitle => 'Install';

  @override
  String get installLauncherName => 'Modded Launcher';

  @override
  String get installLauncherDesc =>
      'Launcher with YNavi set as the default navigation app';

  @override
  String get installYnaviName => 'YNavi mod (HUD)';

  @override
  String get installYnaviDesc =>
      'Yandex.Navi mod with HUD support and minimap broadcast';

  @override
  String get installButtonLabel => 'Install / Update';

  @override
  String get installPhaseDownloading => 'Downloading…';

  @override
  String get installPhaseInstalling => 'Installing…';

  @override
  String get installPhaseDone => 'Done';

  @override
  String get installPhaseFailed => 'Failed';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get langSectionApp => 'App language';

  @override
  String get langSectionSystem => 'System language';

  @override
  String get langSectionCluster => 'Cluster language';

  @override
  String get langCarOnly => 'Available on the car only';

  @override
  String get langCurrentValue => 'Current';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get hudSettingsTitle => 'HUD Settings';

  @override
  String get blinkerSection => 'Blinker';

  @override
  String get blinkerShape => 'Shape';

  @override
  String get blinkerShapeDots => 'Dots';

  @override
  String get blinkerShapeArrows => 'Arrows';

  @override
  String get blinkerShapeSmiley => 'Smiley';

  @override
  String get blinkerSize => 'Size';

  @override
  String get blinkerVerticalPosition => 'Vertical position';

  @override
  String get blinkerSidePadding => 'Side padding (from edge)';

  @override
  String get batterySection => 'Battery';

  @override
  String get showBattery => 'Show battery indicator';

  @override
  String get showTemp => 'Show temperature';

  @override
  String get showChargingStats => 'Show charging stats (while charging)';

  @override
  String get batteryContentMode => 'Content';

  @override
  String get batteryContentBoth => 'Both';

  @override
  String get batteryContentIconOnly => 'Icon';

  @override
  String get batteryContentTextOnly => 'Text';

  @override
  String get batteryStyle => 'Look';

  @override
  String get batteryStyleOutline => 'Outline';

  @override
  String get batteryStyleFilled => 'Blocks';

  @override
  String get batteryStylePctInside => '% inside';

  @override
  String get batterySize => 'Size';

  @override
  String get safeAreaSection => 'Safe Area (fractions)';

  @override
  String get safeAreaInset => 'Safe Area inset';

  @override
  String get positionTop => 'Top';

  @override
  String get positionBottom => 'Bottom';

  @override
  String get positionEdge => 'Edge';

  @override
  String get sectionMinimap => 'Minimap';

  @override
  String get sectionMinimapSubtitle => 'YNavi minimap, size, colour look';

  @override
  String get minimapTitle => 'Minimap';

  @override
  String get minimapSection => 'Minimap';

  @override
  String get minimapEnable => 'Enable minimap';

  @override
  String get minimapYnaviUnavailableHint =>
      'Install a compatible YNavi mod to enable the minimap';

  @override
  String get minimapPreset => 'Preset';

  @override
  String get minimapPresetCompact => 'Compact';

  @override
  String get minimapPresetBalanced => 'Balanced';

  @override
  String get minimapPresetLarge => 'Large';

  @override
  String get minimapAdvanced => 'Advanced';

  @override
  String get minimapSize => 'Size (fraction of safe area)';

  @override
  String get minimapLookSection => 'Look';

  @override
  String get minimapLookPreset => 'Colour preset';

  @override
  String get minimapLookPresetGreenYellow => 'Green-yellow';

  @override
  String get minimapLookPresetWhite => 'White';

  @override
  String get minimapLookPresetAmber => 'Amber';

  @override
  String get minimapLookPresetCyan => 'Cyan';

  @override
  String get minimapLookBrightness => 'Brightness';

  @override
  String get minimapLookContrast => 'Contrast';

  @override
  String get sectionUsbAdb => 'USB / ADB';

  @override
  String get sectionUsbAdbSubtitle => 'USB host/peripheral mode';

  @override
  String get usbAdbTitle => 'USB / ADB';

  @override
  String get usbModePeripheral => 'Peripheral';

  @override
  String get usbModeHost => 'Host';

  @override
  String get usbModeAuto => 'Auto';

  @override
  String get usbCurrentMode => 'Current';

  @override
  String get usbPlatformSigningRequired =>
      'Actually changing the USB mode requires platform (system) signing, which this build does not have — on the emulator or the car. Your selection is saved, but the USB role itself will not change until the app is platform-signed.';

  @override
  String get hudSlotMinimap => 'MINIMAP';

  @override
  String get hudFullDisplayToggle => 'Full display';

  @override
  String get hudFullDisplayToggleSubtitle =>
      'Show the whole backing display, with the Safe Area outlined (debug)';

  @override
  String get hudPreviewBadgeDemo => 'PREVIEW · DEMO';

  @override
  String get hudPreviewBadgeLive => 'LIVE · SIMULATED';

  @override
  String get minimapPresetDisabledHint => 'Custom dimensions active';

  @override
  String get sectionSimulate => 'Simulate';

  @override
  String get sectionSimulateSubtitle => 'Fire live signals to test the HUD';

  @override
  String get simulateTitle => 'Simulate';

  @override
  String get simulateDescription =>
      'Debug only — injects live CarSignals so you can watch the HUD react in real time.';

  @override
  String get simulateBlinkerLabel => 'Blinker';

  @override
  String get simulateOff => 'Off';

  @override
  String get simulateLeft => 'Left';

  @override
  String get simulateRight => 'Right';

  @override
  String get simulateHazard => 'Hazard';

  @override
  String get simulateChargingLabel => 'Charging';

  @override
  String get simulateChargeKwLabel => 'Charge power';

  @override
  String get simulateBatteryLabel => 'Battery level';

  @override
  String get simulateBatteryTempLabel => 'Battery temperature';

  @override
  String get simulateSpeedLabel => 'Speed';

  @override
  String get homeTitle => 'Zee Power Toys';

  @override
  String get homeWelcomeTitle => 'Welcome';

  @override
  String get homeWelcomeBody =>
      'HUD overlays and minimap for Zeekr. Check companion apps below, then open a section.';

  @override
  String get homeCompanionsTitle => 'Companion apps';

  @override
  String get homeSectionsTitle => 'Sections';

  @override
  String get homeStatusInstalled => 'Installed';

  @override
  String get homeStatusMissing => 'Missing';

  @override
  String get homeStatusUnknown => 'Unknown';

  @override
  String get homeInstallAction => 'Install';
}
