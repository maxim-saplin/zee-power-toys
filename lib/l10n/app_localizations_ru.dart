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
  String get diagSectionSource => 'Источник сигнала';

  @override
  String get diagSignalSource => 'Источник';

  @override
  String get diagSignalSourceAdaptApi => 'AdaptAPI (автомобиль)';

  @override
  String get diagSignalSourceSimulated => 'Симуляция (эмулятор)';

  @override
  String get diagSignalSourceFake => 'Заглушка (десктоп)';

  @override
  String get diagSignalSourceUnknown => 'Неизвестно';

  @override
  String get diagHudDisplay => 'Дисплей HUD';

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
  String get sectionInstallSubtitle => 'Модифицированный лаунчер и мод YNavi';

  @override
  String get installTitle => 'Установка';

  @override
  String get installLauncherName => 'Модифицированный лаунчер';

  @override
  String get installLauncherDesc =>
      'Лаунчер с YNavi в качестве навигации по умолчанию';

  @override
  String get installYnaviName => 'Мод YNavi (HUD)';

  @override
  String get installYnaviDesc =>
      'Мод Яндекс.Навигатора с поддержкой HUD и трансляцией миникарты';

  @override
  String get installButtonLabel => 'Установить / Обновить';

  @override
  String get installPhaseDownloading => 'Загрузка…';

  @override
  String get installPhaseInstalling => 'Установка…';

  @override
  String get installPhaseDone => 'Готово';

  @override
  String get installPhaseFailed => 'Ошибка';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSystem => 'По умолчанию (системное)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get langSectionApp => 'Язык приложения';

  @override
  String get langSectionSystem => 'Язык системы';

  @override
  String get langSectionCluster => 'Язык приборной панели';

  @override
  String get langCarOnly => 'Доступно только в автомобиле';

  @override
  String get langCurrentValue => 'Текущий';

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
  String get batteryContentMode => 'Содержимое';

  @override
  String get batteryContentBoth => 'Оба';

  @override
  String get batteryContentIconOnly => 'Значок';

  @override
  String get batteryContentTextOnly => 'Текст';

  @override
  String get batteryStyle => 'Вид';

  @override
  String get batteryStyleOutline => 'Контур';

  @override
  String get batteryStyleFilled => 'Блоки';

  @override
  String get batteryStylePctInside => '% внутри';

  @override
  String get batterySize => 'Размер';

  @override
  String get safeAreaSection => 'Безопасная область (доли)';

  @override
  String get safeAreaInset => 'Отступ безопасной области';

  @override
  String get positionTop => 'Сверху';

  @override
  String get positionBottom => 'Снизу';

  @override
  String get positionEdge => 'Край';

  @override
  String get sectionMinimap => 'Миникарта';

  @override
  String get sectionMinimapSubtitle => 'Миникарта YNavi, размер, цвет';

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
  String get minimapSize => 'Размер (доля безопасной области)';

  @override
  String get minimapLookSection => 'Вид';

  @override
  String get minimapLookPreset => 'Цветовой пресет';

  @override
  String get minimapLookPresetGreenYellow => 'Зелёно-жёлтый';

  @override
  String get minimapLookPresetWhite => 'Белый';

  @override
  String get minimapLookPresetAmber => 'Янтарный';

  @override
  String get minimapLookPresetCyan => 'Голубой';

  @override
  String get minimapLookBrightness => 'Яркость';

  @override
  String get minimapLookContrast => 'Контраст';

  @override
  String get sectionUsbAdb => 'USB / ADB';

  @override
  String get sectionUsbAdbSubtitle => 'Режим USB: хост/устройство';

  @override
  String get usbAdbTitle => 'USB / ADB';

  @override
  String get usbModePeripheral => 'Периферийное устройство';

  @override
  String get usbModeHost => 'Хост';

  @override
  String get usbModeAuto => 'Авто';

  @override
  String get usbCurrentMode => 'Текущий';

  @override
  String get usbPlatformSigningRequired =>
      'Для фактического переключения режима USB нужна системная подпись, которой у этой сборки нет — ни на эмуляторе, ни в автомобиле. Выбор сохраняется, но сам режим USB не изменится, пока приложение не будет подписано системным ключом.';

  @override
  String get hudSlotMinimap => 'МИНИКАРТА';

  @override
  String get hudFullDisplayToggle => 'Полный экран';

  @override
  String get hudFullDisplayToggleSubtitle =>
      'Показать весь дисплей HUD целиком, с обводкой Safe Area (отладка)';

  @override
  String get hudPreviewBadgeDemo => 'ПРЕДПРОСМОТР · ДЕМО';

  @override
  String get hudPreviewBadgeLive => 'ЖИВОЙ · СИМУЛЯЦИЯ';

  @override
  String get minimapPresetDisabledHint => 'Активны пользовательские размеры';

  @override
  String get sectionSimulate => 'Симуляция';

  @override
  String get sectionSimulateSubtitle =>
      'Отправка живых сигналов для проверки HUD';

  @override
  String get simulateTitle => 'Симуляция';

  @override
  String get simulateDescription =>
      'Только для отладки — отправляет живые сигналы CarSignals, чтобы вы могли увидеть реакцию HUD в реальном времени.';

  @override
  String get simulateBlinkerLabel => 'Поворотник';

  @override
  String get simulateOff => 'Выкл';

  @override
  String get simulateLeft => 'Налево';

  @override
  String get simulateRight => 'Направо';

  @override
  String get simulateHazard => 'Аварийка';

  @override
  String get simulateChargingLabel => 'Зарядка';

  @override
  String get simulateChargeKwLabel => 'Мощность зарядки';

  @override
  String get simulateBatteryLabel => 'Уровень заряда';

  @override
  String get simulateBatteryTempLabel => 'Температура батареи';

  @override
  String get simulateSpeedLabel => 'Скорость';

  @override
  String get homeTitle => 'Zee Power Toys';

  @override
  String get homeWelcomeTitle => 'Добро пожаловать';

  @override
  String get homeWelcomeBody =>
      'HUD-оверлеи и миникарта для Zeekr. Проверьте приложения ниже и откройте раздел.';

  @override
  String get homeCompanionsTitle => 'Сопутствующие приложения';

  @override
  String get homeSectionsTitle => 'Разделы';

  @override
  String get homeStatusInstalled => 'Установлено';

  @override
  String get homeStatusMissing => 'Нет';

  @override
  String get homeStatusUnknown => 'Неизвестно';

  @override
  String get homeInstallAction => 'Установить';
}
