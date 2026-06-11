// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Zee Power Toys';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get sectionHud => 'HUD';

  @override
  String get sectionHudSubtitle => 'Поворотники, аккумулятор, компоновка';

  @override
  String get sectionDiagnostics => 'Диагностика';

  @override
  String get sectionDiagnosticsSubtitle => 'Текущие показатели автомобиля';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get diagSectionMotion => 'Движение';

  @override
  String get diagSectionLighting => 'Освещение';

  @override
  String get diagSectionEnergy => 'Энергия';

  @override
  String get diagSectionBattery => 'Аккумулятор';

  @override
  String get diagSpeed => 'Скорость';

  @override
  String get diagPowerFlow => 'Поток мощности';

  @override
  String get diagPowerFlowUnknown => 'неизвестно';

  @override
  String get diagPowerFlowDrive => 'тяга';

  @override
  String get diagPowerFlowRegen => 'рекуперация';

  @override
  String get diagPowerFlowStandstill => 'стоянка';

  @override
  String get diagBlinker => 'Поворотник';

  @override
  String get diagBlinkerOff => 'выкл';

  @override
  String get diagBlinkerLeft => 'левый';

  @override
  String get diagBlinkerRight => 'правый';

  @override
  String get diagBlinkerHazard => 'аварийная';

  @override
  String get diagCharging => 'Зарядка';

  @override
  String get diagChargePower => 'Мощность зарядки';

  @override
  String get diagYes => 'да';

  @override
  String get diagNo => 'нет';

  @override
  String get diagBatteryLevel => 'Уровень заряда';

  @override
  String get diagBatteryTemp => 'Температура батареи';

  @override
  String get diagRawSnapshot => 'Сырые данные';

  @override
  String get sectionLanguage => 'Язык';

  @override
  String get sectionLanguageSubtitle => 'Язык отображения приложения';

  @override
  String get sectionInstall => 'Установка';

  @override
  String get sectionInstallSubtitle => 'Скоро будет доступно';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSystem => 'По умолчанию';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get comingSoon => 'Скоро будет доступно';

  @override
  String get hudSettingsTitle => 'Настройки HUD';

  @override
  String get blinkerSection => 'Поворотники';

  @override
  String get blinkerShape => 'Форма';

  @override
  String get blinkerShapeDots => 'Точки';

  @override
  String get blinkerShapeArrows => 'Стрелки';

  @override
  String get blinkerShapeSmiley => 'Смайлик';

  @override
  String get blinkerSize => 'Размер';

  @override
  String get blinkerVerticalPosition => 'Вертикальное положение';

  @override
  String get blinkerSidePadding => 'Боковой отступ (от края)';

  @override
  String get batterySection => 'Аккумулятор';

  @override
  String get showBattery => 'Показывать индикатор заряда';

  @override
  String get showTemp => 'Показывать температуру';

  @override
  String get showChargingStats => 'Показывать данные зарядки (при зарядке)';

  @override
  String get safeAreaSection => 'Безопасная область (доли)';

  @override
  String get safeAreaInset => 'Отступ безопасной области';

  @override
  String get debugHudBox => 'Отладочная рамка HUD';

  @override
  String get positionTop => 'Сверху';

  @override
  String get positionBottom => 'Снизу';

  @override
  String get positionEdge => 'Край';

  @override
  String get sectionMinimap => 'Миникарта';

  @override
  String get sectionMinimapSubtitle =>
      'Миникарта YNavi, пресеты, темная/светлая';

  @override
  String get minimapTitle => 'Миникарта';

  @override
  String get minimapSection => 'Миникарта';

  @override
  String get minimapEnable => 'Включить миникарту';

  @override
  String get minimapYnaviUnavailableHint =>
      'Установите совместимый мод YNavi, чтобы включить миникарту';

  @override
  String get minimapPreset => 'Пресет';

  @override
  String get minimapPresetCompact => 'Компактный';

  @override
  String get minimapPresetBalanced => 'Стандартный';

  @override
  String get minimapPresetLarge => 'Большой';

  @override
  String get minimapAdvanced => 'Расширенно';

  @override
  String get minimapWidth => 'Ширина (доля безопасной области)';

  @override
  String get minimapHeight => 'Высота (доля безопасной области)';

  @override
  String get minimapThemeSection => 'Тема';

  @override
  String get minimapThemeAuto => 'Системная (авто)';

  @override
  String get minimapThemeDark => 'Тёмная';

  @override
  String get minimapThemeLight => 'Светлая';
}
