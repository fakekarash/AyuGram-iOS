# AyuGram iOS: проверочная сборка, 2026-10-13

## Продолжение после разрешения владельца

После первоначальной подготовки владелец поручил самостоятельно настроить GitHub
и запустить сборку. Создан публичный форк
[`fakekarash/AyuGram-iOS`](https://github.com/fakekarash/AyuGram-iOS), исходный HEAD
совпал с локальным `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`.
Оба Repository secrets добавлены через интерфейс GitHub без записи значений в
файлы/вывод инструментов. Старый `CI` отключён (`disabled_manually`).

Опубликованы CI-helper (commit `17ce5c1faa4c35cb18b4d352acae565d8f07e729`)
и ручной workflow (commit `db5e634996e328aad800987fed7ab620da688772`).
Оба файла побайтно сверены с локальными. Ручной
[run №1](https://github.com/fakekarash/AyuGram-iOS/actions/runs/38464997255)
создан на втором commit; на момент этой записи он в очереди.
Это ещё не успешная сборка и не подтверждение наличия IPA.

Локальный `origin` сохранён, добавлен отдельный remote `fork`. Выполнен fetch
только для чтения опубликованных коммитов; локальная ветка и первоначальные
изменения пользователя не перезаписаны. Разделы ниже описывают первоначальный
аудит ДО публикации, а инструкция запуска сохранена для последующих запусков.

## Фактически проверено локально

- Ветка `master`, HEAD `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`
  (`Merge branch 'beta'`). `git status` не показывал расхождения с локальным
  `origin/master`; свежий fetch не выполнялся.
- `origin` пока указывает на `https://github.com/TelegramMessenger/Telegram-iOS.git`,
  а не на личный форк. Remotes не менялись.
- `git config --local --get core.longpaths` вернул `true`.
- Все 13 подмодулей из `git submodule status --recursive` инициализированы,
  соответствуют gitlink-коммитам, имеют чистый status. Обновлять их не потребовалось.
  Проверка была рекурсивной; дополнительных вложенных gitlink-подмодулей не обнаружено.
- Прочитаны `README.md`, `versions.json`, оба существовавших workflow,
  сборщик `Make.py`, конфигурация и правила упаковки `Telegram/BUILD`.
- Пройден actionlint **v1.7.12** для нового workflow. ShellCheck и Pyflakes
  не установлены и были отключены; это не полная проверка всех внешних команд.
- Пройдены синтаксическая проверка Python, проверка закреплённых версий,
  11 проверок CI-helper (невалидные API-параметры, фильтрация stdout/stderr,
  отсутствие API-переменных у дочернего процесса, распространение ошибки команды,
  отсутствующий/невалидный IPA, manifest для синтетического ZIP).
  В последней проверке `lipo` подменён: это НЕ проверка реального Mach-O/IPA.
- Аргументы сборки сверены с объявлениями argparse в исходном `Make.py`.
- Локальный preflight ожидаемо завершился ошибкой: требуется macOS 26 ARM64.
  Даже `Make.py build --help` на Windows падает при импорте macOS-модуля `fcntl`.
  Изменения upstream ради запуска на Windows не вносились.

**GitHub Actions не запускался. Реальной smoke-сборки, IPA в Artifacts и проверки
установки на iPhone пока нет.** Коммит, push, Release, создание secrets и другие
внешние изменения не выполнялись. Ghost Mode, Anti-Recall и другие функции не добавлялись.

## Сохранённые изменения и новые файлы

Следующие изменения существовали ДО этой работы и оставлены без изменения:

- `.gitignore` — два исключения для локальных конфигураций;
- `.github/workflows/ayugram-smoke-ipa.yml`;
- `build-system/ayugram-development-configuration.example.json`;
- `docs/AYUGRAM_WINDOWS_CI.md`.

Для сохранения этого черновика добавлены отдельные файлы:

- `.github/workflows/ayugram-baseline-ipa.yml` — **AyuGram iOS baseline IPA (manual)**;
- `build-system/ayugram_ci.py` — проверка окружения, сборка с фильтрацией логов,
  временная тестовая подпись и проверка IPA;
- `docs/AYUGRAM_BASELINE_AUDIT.md` — этот отчёт и порядок первого запуска.

## Закреплённое окружение

| Компонент | Требование |
| --- | --- |
| macOS | major **26**, как в `versions.json`; patch образа GitHub может меняться |
| Runner | **`macos-26` (ARM64)**; не `macos-latest`, `macos-13` или Intel |
| Xcode для сборки | **26.6**, `/Applications/Xcode_26.6.app/Contents/Developer` |
| `deploy_xcode` | **26.2**, отдельное поле; не замена Xcode сборки |
| Bazel | **9.2.0**, бинарник `darwin-arm64` |
| SHA256 Bazel | `dd466352a3e4d3581b8898740ee1ff208866ccbe25f8d367c5dcb950219587e6` |
| Конфигурация приложения | upstream `Telegram/Telegram`, `release_arm64`, версия **13.0** |

Xcode 26.6 указан в [официальном ARM64-образе GitHub](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).
Соответствие `macos-26` архитектуре ARM64 подтверждается
[справочником runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
SHA256 из `versions.json` совпал с опубликованным
[checksum Bazel 9.2.0 ARM64](https://github.com/bazelbuild/bazel/releases/download/9.2.0/bazel-9.2.0-darwin-arm64.sha256).
Сам бинарник Bazel здесь не запускался. CI скачивает его, сверяет SHA256 и версию
до получения API-secrets. Проверки Xcode/Bazel не обходятся; смена pins требует
явного пересмотра helper и runner.

## Как работает новый workflow

Только `workflow_dispatch`; нет push, pull_request, расписания, Release или прав
записи в contents. Checkout не сохраняет GitHub credentials. Подмодули получают
закреплённые коммиты, без `--remote` или `--force`. Два относительных upstream URL
переопределяются только в локальной git-конфигурации runner на публичные
`TelegramMessenger/rlottie.git` и `TelegramMessenger/tgcalls.git`.

Ровно два пользовательских Repository secrets:

| Secret | Значение |
| --- | --- |
| `TELEGRAM_API_ID` | Собственный положительный числовой API ID приложения |
| `TELEGRAM_API_HASH` | Собственный API hash из 32 hex-символов |

Получить их можно на [my.telegram.org/apps](https://my.telegram.org/apps).
Значения не передаются через workflow inputs или аргументы Make/Bazel, не
записываются в версионируемые файлы и фильтруются перед выводом логов дочерних
команд. Конфигурация создаётся в `RUNNER_TEMP` с ограниченными правами и удаляется
в `finally`. Make.py также временно создаёт игнорируемый `build-input/.../variables.bzl`;
helper удаляет его после сборки. Build cache и сырые логи не загружаются.
Секреты по природе клиента входят в скомпилированный бинарник: IPA не является
способом хранить их в тайне от получателя. Сам IPA публикуется только как Actions
Artifact с доступом согласно настройкам репозитория.

Используются ТОЛЬКО публичные upstream fake-сертификаты и профили, уже находящиеся
в репозитории. Они импортируются в отдельный временный keychain runner, который
удаляется по завершении. Apple ID, пароль, 2FA, личный `.p12`, Apple provisioning
profiles или Apple secrets от пользователя не нужны. Новые сертификаты не создаются.

Сохраняются upstream bundle/team IDs для соответствия fake profiles. Полученный
артефакт — промежуточный клиент Telegram для проверки сборки, требующий переподписи,
не готовый подписанный релиз AyuGram. Шесть iOS-расширений включены штатными правилами;
Watch app не запрашивается (upstream default). Список реально упакованных расширений
будет в `manifest.json`.

CI проверяет CRC ZIP, единственное основное приложение, bundle ID, device platform,
непустой исполняемый файл и ARM64 через `lipo`. Затем загружает только `Telegram.ipa`
и `manifest.json` с SHA256, commit, версиями и подмодулями. Ошибка сборки/проверки
блокирует upload. Успех означает **зелёный run + существующий Artifact с IPA**,
а не только созданный YAML или успешный checkout. Проверка настоящей подписи,
запуска, авторизации Telegram и уведомлений на устройстве остаётся отдельной.

## Первый запуск в GitHub — только после разрешённой публикации файлов

1. Использовать собственный форк; текущий `origin` указывает на upstream.
   Подготовленные файлы пока только локальные. Их commit/push и настройка remote
   требуют отдельного указания владельца.
2. **Перед push в `master` отключить старый `CI` (`build.yml`) в своём форке:**
   Actions → CI → меню `…` → Disable workflow. Он по-прежнему содержит push-trigger,
   `macos-13` и автоматический Create Release. Этот существующий файл не менялся.
   Если Actions ещё отключены, не включать старый CI при первой настройке форка.
3. После отдельно разрешённой публикации поместить новый workflow и helper в
   default branch. GitHub показывает ручной запуск, когда workflow есть в default
   branch: [инструкция GitHub](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).
4. Settings → Secrets and variables → Actions → **New repository secret**:
   создать `TELEGRAM_API_ID` и `TELEGRAM_API_HASH`. Ничего из Apple не добавлять.
5. Actions → **AyuGram iOS baseline IPA (manual)** → **Run workflow** → выбрать
   нужную ветку → **Run workflow**. Не выбирать старые `CI` и `AyuGram iOS smoke IPA`.
6. Дождаться полного зелёного run. Открыть его Summary → **Artifacts** →
   `ayugram-baseline-ipa-<run_number>-<run_attempt>`. Скачать архив и убедиться,
   что внутри есть непустой `Telegram.ipa` и `manifest.json`. Хранение — 7 дней.

## Ограничения установки и пока не проверенные предположения

- Бесплатный Apple Account: профиль действует **7 дней**, требуется регулярная
  повторная подпись/refresh. До **10 App ID**, истекающих через 7 дней, и до
  **3 установленных приложений** на устройстве. Это ограничения Apple, а не
  конкретного IPA: [Apple Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account).
- Каждое расширение расходует отдельный App ID. В текущем `Telegram/BUILD` шесть:
  Share, NotificationContent, NotificationService, Intents, Widget, BroadcastUpload.
  Основное приложение вместе с ними потенциально занимает **7 App ID**, плюс
  идентификаторы уже установленных приложений/установщика. Удаление расширений
  инструментом переподписи экономит IDs ценой соответствующих функций:
  [AltStore App IDs](https://faq.altstore.io/altstore-classic/app-ids).
- **AltStore Classic:** сам занимает один из трёх слотов; обычный refresh требует
  доступного AltServer (Wi-Fi/USB). Проверить работу фонового обновления до истечения
  7 дней: [AltServer](https://faq.altstore.io/altstore-classic/altserver).
- **SideStore:** сам входит в лимит трёх приложений; настроить pairing и локальное
  сетевое подключение согласно текущей инструкции, проверить первый refresh.
  Лимиты App ID и 7 дней сохраняются:
  [FAQ](https://docs.sidestore.io/docs/faq), [установка](https://docs.sidestore.io/docs/installation/install).
- **Sideloadly:** повторная подпись с компьютера; auto-refresh зависит от работающего
  daemon и доступности устройства. Бесплатная подпись тоже на 7 дней:
  [официальный FAQ](https://sideloadly.io/).
- **APNs/push нельзя обещать.** Нужны допустимый `aps-environment`, профиль с push
  capability и серверная авторизация для соответствующего app/topic. Чужие upstream
  entitlements и fake profiles не предоставляют этих прав; простой re-sign не
  настраивает инфраструктуру Telegram для нового App ID. См.
  [регистрацию APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
  и [отправку APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).
- App Groups, Keychain access groups, Associated Domains, iCloud, Siri,
  communication/filtering notifications и другие entitlement должны соответствовать
  новой подписи и профилю. Исходные group/team IDs нельзя безусловно переносить.
  Инструмент может их удалить/заменить; возможны ошибки установки, общий контейнер
  расширений и потеря части функций. Siri/iCloud уже отключены в smoke-конфигурации,
  остальные ограничения реальны даже при успешной сборке. См.
  [возможности Apple](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).
- Достаточность CPU/RAM/диска стандартного ARM64 runner и лимита 330 минут неизвестна
  до первого запуска. Полная сборка Telegram тяжёлая; версия окружения подходит,
  но это не гарантия достаточности ресурсов. При нехватке нужен более мощный
  ARM64 macOS 26 runner с Xcode 26.6, после отдельного решения владельца.

До успешной базовой CI-сборки не переходить к функциям AyuGram. Затем отдельно
проверить переподпись, установку, запуск и авторизацию на конкретной версии iOS.
