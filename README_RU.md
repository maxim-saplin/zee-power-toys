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

### В машине (DHU)

1. Установите **platform-signed** release APK (`sharedUserId` / AOSP debug key).
2. Откройте **Zee Power Toys** → разрешите геолокацию, когда спросит Speedcam.
3. Опционально компаньоны через **Install**: мод YNavi + мод лаунчера (GitHub Releases).
4. Включите HUD / Speedcam / Minimap в настройках. Самообновление: **Install → Check for updates**.

```bash
flutter build apk --release -PuseAospDebugKey=true
adb install -g -r -d build/app/outputs/flutter-apk/app-release.apk
```

**Не делайте `adb uninstall`** в повседневной работе — сотрёт настройки. Предпочитайте `install -r`.
См. [0054](docs/issues/0054-settings-survive-reinstall.md).

### Самообновление (GitHub Releases)

Когда есть публичный Release этого репозитория:

- **Тег:** `1.0.0+N` (или `v1.0.0+N`) — `N` = build / versionCode  
- **Ассет:** `zee-power-toys.apk` (запасной `app-release.apk`)  
- В приложении: **Install → Check for updates → Update now**

CI: тег `1.0.0+N` (или `workflow_dispatch`) → `release.yml` загружает `zee-power-toys.apk`.

### Рабочий стол (T1)

```bash
uv run dev/zee_run.py up    # Linux (или macOS с раннером macos/)
```

На T1 миникарта — фейк; для поверхности YNavi нужны T2 эмулятор / T3 машина.

---

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
| _заглушка — иконки Maxim_ | _заглушка_ | _заглушка_ |

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
