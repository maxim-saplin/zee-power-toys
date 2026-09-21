# Zee Power Toys

**[EN](README.md) | [RU](README_RU.md)**

**HUD на лобовом стекле + утилиты DHU для головных устройств Zeekr (Android).**

Приложение для центрального дисплея автомобиля (DHU) и HUD: миникарта навигации,
поворотники, предупреждения о камерах, заряд/батарея, язык и установка компаньонов —
без борьбы со штатным UI.

| | |
|---|---|
| **Это приложение** | [maxim-saplin/zee-power-toys](https://github.com/maxim-saplin/zee-power-toys) |
| **Мод YNavi (карта HUD)** | [maxim-saplin/ynavi-zee](https://github.com/maxim-saplin/ynavi-zee) |
| **Мод лаунчера** | [maxim-saplin/zeekr_apk_mod](https://github.com/maxim-saplin/zeekr_apk_mod) |

> Скриншоты ниже — TBD (арт для стора ещё в работе). На установку и tips это не влияет.

---


## Поддержка

| | |
|---|---|
| **Проверено** | **Zeekr 007**, Zeekr OS **6.7** |
| **Ожидается** | **Zeekr 001**, ПО **6.3+** |

Честно: гоняем на 007 / 6.7. На 001 и 6.3+ тот же стек DHU должен подходить, но как tested мы их не закрывали.

## Быстрый старт

### A. Установка на DHU (без ПК)

1. На планшете авто откройте страницу [Releases](https://github.com/maxim-saplin/zee-power-toys/releases) в браузере и скачайте **`zee-power-toys.apk`** с последнего тега (`1.0.0+N`).
2. Откройте скачанный APK (Файлы / Загрузки) и установите системным установщиком.
3. Если Android блокирует: разрешите **установку из этого источника** (браузер / Файлы) по запросу — обычное дело для sideload.
4. Откройте **Zee Power Toys**. Разрешите **геолокацию**, когда спросит Speedcam (runtime-диалог, не на этапе установки).
5. Опционально: компаньоны через **Install** в приложении (YNavi / лаунчер с их Releases). Самообновление позже: **Install → Check for updates**.

**Права, которые могут потребовать отдельный экран (не CLI):**
- **Геолокация** — диалог в приложении при первом запросе Speedcam.
- **Показ поверх других окон** (`SYSTEM_ALERT_WINDOW`) — только если включите системный оверлей Speedcam на DHU; Android откроет Settings.
- «Неизвестные источники» / install unknown apps — один раз на приложение-установщик (браузер/Файлы).

В повседневной работе не делайте uninstall «для обновления» — сотрёт настройки. Предпочитайте replace/update. См. [0054](docs/issues/0054-settings-survive-reinstall.md).

### B. Установка с рабочей станции (`adb`)

1. На ПК/Mac скачайте **`zee-power-toys.apk`** с [Releases](https://github.com/maxim-saplin/zee-power-toys/releases).
2. На DHU: инженерное меню (яркая оранжевая кнопка сверху по центру — ~10 нажатий) → ADB в режим **Peripheral**, затем USB к рабочей станции.
3. Установите [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools), чтобы `adb` был в `PATH`.
4. Проверьте устройство и установите (с сохранением данных):

```bash
adb devices
adb install -g -r -d zee-power-toys.apk
```

`-g` выдаёт runtime-права, где позволяет платформа; диалоги геолокации / оверлея выше всё равно могут появиться.

### Самообновление (уже установлено)

- Актуальный ассет: `zee-power-toys.apk` на теге `1.0.0+N`
- В приложении: **Install → Check for updates → Update now**


## Что внутри

- **HUD** — поворотники, батарея/заряд, Safe-Area, Config Preview  
- **Minimap** — YNavi на лобовом (нужен мод YNavi; обычно и лаунчер)  
- **Speedcam** — пакеты OSM, алерты на приближении, виды Default/Alien, Demo на HUD  
  **YNavi не обязателен** — достаточно OSM-паков  
- **DHU** — язык/кластер, Install компаньонов, диагностика, USB/ADB  
- **Самообновление** — публичные GitHub Releases → PackageInstaller  

---

## Скриншоты

| Главная DHU | Speedcam | Превью HUD |
|-------------|----------|------------|
| _скриншот TBD_ | _заглушка_ | _заглушка_ |

Кладите PNG в `docs/assets/` (например `dhu-home.png`) и ссылайтесь здесь, когда будут готовы.

---

## Компаньоны (APK)

Для Speedcam необязательны; для миникарты / интеграции навигации по умолчанию — нужны.

| Компаньон | Репозиторий | Release |
|-----------|-------------|---------|
| YNavi с отступом (по умолчанию) | [ynavi-zee](https://github.com/maxim-saplin/ynavi-zee) | тег `ynavi-zeekr-v12` / `zeekr_v12_margined.apk` |
| YNavi OS7+ (без левого отступа) | тот же | тот же тег / `zeekr_v12_os7_nomargin.apk` |
| Мод лаунчера Zeekr | [zeekr_apk_mod](https://github.com/maxim-saplin/zeekr_apk_mod) | тег `launcher-670` / `XCLauncher3-670-yandex-signed.apk` |

**Install UI** качает ассеты Release и запускает `PackageInstaller`.  
**Геолокация** — runtime (диалог в приложении), не на этапе установки. `adb pm grant` — только для лаборатории.


---

## Версионирование

`pubspec.yaml`: **`MAJOR.MINOR.PATCH+BUILD`** (с `1.0.0+1`).  
На каждый tip/car APK поднимайте `+BUILD`; semver — для пользовательских релизов.  
Держите `lib/app_version.dart` в синхроне. См. [CHANGELOG.md](CHANGELOG.md).

---

## Благодарности

Точки **Speedcam** — из [OpenStreetMap](https://www.openstreetmap.org/)
(© участники OpenStreetMap), [ODbL](https://opendatacommons.org/licenses/odbl/).

---

## Для контрибьюторов

Глоссарий: [`CONTEXT.md`](CONTEXT.md) · Требования: [`REQUIREMENTS.md`](REQUIREMENTS.md) · ADR: [`docs/adr/`](docs/adr/) · Блоки: [`docs/issues/`](docs/issues/).


### Подпись релиза / CI

Локальные / car APK используют **закоммиченный** AOSP platform debug keystore:

| | |
|---|---|
| **Keystore** | `android/tools/zeekr/androiddebugkey.jks` |
| **Alias / pass** | из `android/gradle.properties` |
| **Сборка** | `flutter build apk --release -PuseAospDebugKey=true` |
| **Установка** | `adb install -g -r -d build/app/outputs/flutter-apk/app-release.apk` |
| **Публикация** | тег `1.0.0+N` (или Actions → **release** → `workflow_dispatch`) → `release.yml` загружает `zee-power-toys.apk` |
| **Push CI** | `ci.yml` на `main`: analyze + test |

Подробнее: [docs/publish/ci-release.md](docs/publish/ci-release.md).

### Рабочий стол (T1)

```bash
uv run dev/zee_run.py up    # Linux (или macOS с раннером macos/)
```

На T1 миникарта — фейк; для поверхности YNavi нужны T2 эмулятор / T3 машина.

### T2 эмулятор (как DHU)

Только AVD **`Tablet_Android_12L`** (API 32 / Android 12L, `medium_tablet`, **2560×1600** @ 320dpi) — то же поколение и разрешение, что у DHU. Не `Medium_Phone` и не `ROOTED_Android_12L` для смоука DHU UI.

```bash
$ANDROID_HOME/emulator/emulator -avd Tablet_Android_12L -gpu host -no-snapshot-load
adb shell wm size   # ожидай Physical size: 2560x1600
```

`adb` может писать `sdk_gphone64_arm64` — это строка Play-образа, не форм-фактор. Смотри `wm size` / пропорции окна.

На google_apis AVD ставь **debug** (или Google-keyed) APK; AOSP-platform **release** с машины сюда не встанет.


### Сборка из исходников

Нужны Flutter SDK ([установка Flutter](https://docs.flutter.dev/get-started/install)), JDK 17+ и Android SDK / Platform Tools. Далее:

```bash
flutter pub get
flutter build apk --release -PuseAospDebugKey=true
adb install -g -r -d build/app/outputs/flutter-apk/app-release.apk
```

Используется закоммиченный keystore `android/tools/zeekr/androiddebugkey.jks` (см. **Подпись релиза / CI** выше).

### Архитектура (в конце)

Flutter рисует **весь** задуманный UI на DHU + HUD как **два движка / два изолята**
(ADR 0001). Kotlin — тонкий хост (Presentation, AdaptAPI, YNavi, boot, оверлеи).
Сервисы (`CarSignals`, `ConfigStore`, `MinimapHost`, …) — порты: Dart-фейки
вне машины, нативные адаптеры в машине (ADR 0002/0003), инъекция Riverpod (ADR 0006).
Проверка через dual-channel Feedback Loop: T1 Desktop / T2 Emulator / T3 Car
(ADR 0004), блок за блоком (ADR 0007).

| Путь | Что |
|------|-----|
| `lib/` | Flutter-приложение (один Dart-мозг на всех тирах) |
| `dev/` | Драйвер Feedback Loop (`zee_drive.py`) — не импортируется из `lib/` |
| `android/`, `linux/` | Платформенные хосты |
| `docs/adr/` | Architecture Decision Records |
| `docs/issues/` | Доска блоков |
| `docs/knowledge/` | База из phase0 / PoC / мода YNavi |
| `_poc/` | Одноразовые PoC топологии |

```bash
uv run dev/feedback_loop.py whoami-all
```
