# SnapSense

Нативное menu-bar приложение для macOS 14+ — «умный захватчик экрана».
Живёт только в строке меню (`LSUIElement = YES`), без иконки в Dock.

Реализованы захват, OCR, копирование текста и **ИИ-ассистент**:

- глобальный хоткей `⌘⇧2` через Carbon (`RegisterEventHotKey`);
- затемнение всех подключённых мониторов и выбор области на любом из них;
- перекрестие, «вырезанное» светлое выделение, живой размер в пикселях с учётом Retina;
- отмена по `Esc` или правому клику;
- снимок области через `SCScreenshotManager.captureImage` (ScreenCaptureKit);
- локальный OCR через Vision (`.accurate`, `ru-RU` + `en-US`, коррекция языка, bounding boxes);
- плавающий HUD в стиле macOS под областью, копирование распознанного текста в буфер;
- выделение ограничено одним дисплеем за операцию (оверлей при этом показывается на всех мониторах);
- тост «Скопировано в буфер» на 1.2 секунды;
- закрытие HUD по `Esc`, кнопке и клику мимо;
- экран с запросом разрешения Screen Recording и кнопкой открытия системных настроек.

### ИИ-ассистент

Кнопка **«ИИ»** в HUD открывает поповер с четырьмя редактируемыми пресетами
и полем для своего вопроса (Enter — отправить). Пресеты умеют отправлять
только OCR-текст, только скриншот или оба вложения.

- Стриминговый ответ с Markdown и блоками кода в отдельной плавающей панели.
- Остановка генерации, копирование ответа с тостом, закрытие по `Esc` или крестику.
- Провайдеры: OpenAI-compatible Chat Completions и Anthropic Messages API.
- Поддержка кастомного Base URL (OpenAI/OpenRouter/Ollama) и двух моделей по умолчанию.
- Ошибки отсутствующего ключа, `401`, `429`, таймаута и отсутствия сети показываются
  прямо в панели ответа; для ошибок конфигурации есть кнопка «Открыть настройки».
- Настройки и пресеты доступны через «Настройки…» (`⌘,`) в меню-баре.

Скриншот масштабируется максимум до 1280 px по длинной стороне, кодируется
в JPEG с качеством 0.8 и отправляется только после явного выбора ИИ-действия.
OCR всегда выполняется локально. API-ключ по требованию проекта хранится
локально в `UserDefaults` (не в Keychain и не в зашифрованном виде).

## Сборка

```bash
xcodegen generate
xcodebuild -project SnapSense.xcodeproj -scheme SnapSense -configuration Debug build
```

Откройте `SnapSense.xcodeproj`, запустите схему SnapSense. Приложение появится
в строке меню (иконка `viewfinder`). При первом захвате разрешите SnapSense
«Запись экрана» в System Settings → Privacy & Security → Screen Recording.
После выдачи разрешения приложение может потребовать перезапуск.

## Структура

```
SnapSense/
  App/                  lifecycle и AppCoordinator
  Models/               CaptureSelection, OCRResult, AIPreset, AISettings, AICaptureContext
  Services/             Carbon hotkey, ScreenCaptureKit, Vision, LLMService,
                        ImageEncoder, AIConfigurationStore, permissions
  UI/Overlay/           мультимониторный выбор области
  UI/HUD/               floating action bar, toast, click-outside/Esc
  UI/AI/                AI popover, streaming response panel, Markdown renderer
  UI/Settings/          окно настроек и редактор пресетов
  UI/MenuBar/           содержимое menu bar
  UI/Permissions/       окно разрешения Screen Recording
  UI/Components/        NSVisualEffectView bridge
  Resources/Info.plist
```

## Пока не реализовано

В этом чекауте всё ещё нет режимов «Сумма» и «Перевод» из Шага 3:
парсера чисел, `TranslationService`, AR-оверлея перевода и соответствующих
секций настроек. OCR-модель уже хранит `boundingBox`, поэтому эти режимы можно
добавлять, не меняя захват и OCR.

## Примеры Base URL

- OpenAI: `https://api.openai.com/v1`
- OpenRouter: `https://openrouter.ai/api/v1`
- Ollama: `http://localhost:11434/v1` (укажите любой непустой API-ключ)

Для удалённых endpoint'ов предпочтителен HTTPS. Локальные HTTP-подключения
разрешены через ATS-исключение для `localhost`.
