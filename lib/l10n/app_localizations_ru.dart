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
  String get sectionHudSubtitle => 'Поворотники, батарея, компоновка';

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
  String get diagSectionBattery => 'Батарея';

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
  String get sectionLanguageSubtitle => 'Язык и оформление';

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
  String get installYnaviName => 'YNavi мод (с полями / по умолчанию)';

  @override
  String get installYnaviDesc =>
      'YNavi с HUD и левым letterbox под боковую панель Zeekr. Для OS7+ — другая карточка.';

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
  String get languageTitle => 'Язык и оформление';

  @override
  String get themeSectionTitle => 'Оформление';

  @override
  String get themeAuto => 'Авто';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

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
  String get batterySection => 'Батарея';

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
  String get batteryLook => 'Вид';

  @override
  String get batteryLookBattery => 'Батарея';

  @override
  String get batteryLookBatteryText => 'Батарея + текст';

  @override
  String get batteryLookBatteryBars => 'Батарея с полосками';

  @override
  String get batteryLookJustText => 'Только текст';

  @override
  String get batteryPlacement => 'Положение';

  @override
  String get batteryPlacementLeft => 'Слева';

  @override
  String get batteryPlacementRight => 'Справа';

  @override
  String get batteryPlacementRightTop => 'Справа сверху';

  @override
  String get batteryVerticalPosition => 'Вертикальное положение';

  @override
  String get batterySidePadding => 'Боковой отступ (от края)';

  @override
  String get batteryHorizBias => 'Горизонтальный сдвиг';

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
  String get minimapOnlyWhileGuidance => 'Только во время ведения';

  @override
  String get minimapOnlyWhileGuidanceHint =>
      'Если включено, миникарта видна только при активной навигации YNavi';

  @override
  String get minimapGuidanceOverlay => 'Подсказки манёвров';

  @override
  String get minimapGuidanceOverlayHint =>
      'Стрелка, дистанция и улица на миникарте (из данных маршрута YNavi)';

  @override
  String get minimapEtaBar => 'Полоса ETA';

  @override
  String get minimapEtaBarHint =>
      'Оставшиеся дистанция, время и прибытие на миникарте';

  @override
  String get minimapOverlayScale => 'Масштаб оверлея';

  @override
  String get minimapOverlayScaleHint =>
      'Уменьшает полосы манёвров и ETA, чтобы влезли в миникарту (независимо от плотности карты)';

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
  String get minimapLookPresetDefault => 'По умолчанию';

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
      'Оверлеи HUD и миникарта для Zeekr. Проверьте приложения ниже, затем выберите раздел справа.';

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

  @override
  String get minimapContentScale => 'Плотность карты';

  @override
  String get minimapContentScaleHint =>
      'Меньше = больше области карты (по умолчанию 0.5)';

  @override
  String get sectionSpeedcam => 'Камеры';

  @override
  String get sectionSpeedcamSubtitle => 'OSM-пакеты, приближение';

  @override
  String get speedcamTitle => 'Камеры';

  @override
  String get speedcamPackSection => 'Кэш камер';

  @override
  String get speedcamPackBy => 'Беларусь (BY)';

  @override
  String get speedcamPackMissing => 'Камер нет — нажмите Обновить';

  @override
  String speedcamPackStatus(int count, String when) {
    return '$count кам. · $when';
  }

  @override
  String get speedcamPackUpdate => 'Собрать (300 км)';

  @override
  String get speedcamPackUpdating => 'Обновление…';

  @override
  String get speedcamRadarSection => 'Радар';

  @override
  String get speedcamHudRadarEnable => 'Радар на HUD';

  @override
  String get speedcamHudMode => 'Радар на HUD';

  @override
  String get speedcamSoundMode => 'Звук оповещения';

  @override
  String get speedcamPresenceAny => 'Любые';

  @override
  String get speedcamPresenceDangerous => 'Опасные';

  @override
  String get speedcamPresenceOff => 'Выкл';

  @override
  String get speedcamDhuRange => 'Дальность оповещения / радара';

  @override
  String get speedcamSoundEnable => 'Звук приближения';

  @override
  String get speedcamSoundVolume => 'Громкость оповещения';

  @override
  String get speedcamRadarLook => 'Вид радара';

  @override
  String get speedcamRadarLookDefault => 'Обычный';

  @override
  String get speedcamRadarLookAlien => 'Alien';

  @override
  String get speedcamHudDemo => 'Демо на HUD';

  @override
  String get speedcamHudDemoStop => 'Стоп демо';

  @override
  String get speedcamDbSection => 'Локальная БД / карта';

  @override
  String get speedcamDbRegion => 'Регион';

  @override
  String get speedcamDbCoverage => 'Охват';

  @override
  String get speedcamDbSource => 'Источник';

  @override
  String get speedcamDbFetched => 'Последнее обновление';

  @override
  String get speedcamDbAge => 'Возраст';

  @override
  String get speedcamDbCount => 'Камер в кэше';

  @override
  String get speedcamDbSample => 'Примеры камер';

  @override
  String get speedcamHarvestSection => 'Сбор / обновление';

  @override
  String get speedcamRefreshPolicy => 'Политика обновления';

  @override
  String get speedcamRefreshManual => 'Только вручную';

  @override
  String get speedcamRefreshIfStale => 'Если устарел';

  @override
  String get speedcamStaleDays => 'Устарел через (дней)';

  @override
  String get speedcamLocationDenied =>
      'Нет доступа к геолокации — разрешите в настройках или в диалоге приложения. Сбор не будет использовать старый центр Demo/Минск.';

  @override
  String get speedcamLocationNeeded =>
      'Разрешите геолокацию, чтобы Speedcam следил за авто и центрировал сбор.';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String get sectionAboutSubtitle => 'Версия и источники данных';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutAppSection => 'Приложение';

  @override
  String get aboutAppName => 'Zee Power Toys';

  @override
  String get aboutVersion => 'Версия';

  @override
  String get aboutCreditsSection => 'Благодарности';

  @override
  String get aboutSpeedcamCreditTitle => 'Камеры / картоданные';

  @override
  String get aboutSpeedcamCreditBody =>
      'Точки камер — OpenStreetMap. © участники OpenStreetMap. Данные по лицензии Open Database License (ODbL).';

  @override
  String get installYnaviOs7Name => 'YNavi мод (OS7+, без левого поля)';

  @override
  String get installYnaviOs7Desc =>
      'Тот же HUD-мод без левого letterbox — для панели Zeekr OS7+.';

  @override
  String get updateCardName => 'Zee Power Toys';

  @override
  String get updateCardDesc =>
      'Проверить GitHub Releases на новую сборку этого приложения и установить.';

  @override
  String get updateCheckButton => 'Проверить обновления';

  @override
  String get updateInstallButton => 'Обновить';

  @override
  String get updateStatusChecking => 'Проверка…';

  @override
  String get updateStatusUpToDate => 'У вас актуальная сборка.';

  @override
  String updateStatusAvailable(String label) {
    return 'Доступно обновление: $label';
  }

  @override
  String get updateStatusNone => 'Публичных релизов пока нет.';

  @override
  String updateStatusFailed(String message) {
    return 'Ошибка проверки: $message';
  }

  @override
  String get speedcamDhuSystemOverlay => 'Системный оверлей DHU';

  @override
  String get speedcamDhuSystemOverlayHint =>
      'Полный радар камер поверх других приложений при приближении (нужно разрешение «поверх окон»).';

  @override
  String get speedcamOverlayPermissionDenied =>
      'Нужно разрешение показа поверх других окон.';
}
