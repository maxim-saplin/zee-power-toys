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
  String get sectionDiagnosticsSubtitle => 'Скоро будет доступно';

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
}
