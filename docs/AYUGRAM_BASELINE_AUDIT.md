# AyuGram iOS: итог baseline smoke-сборки, 2026-10-14

## Результат GitHub Actions

Ручной workflow **AyuGram iOS baseline IPA (manual)** успешно завершился:

- [run №3](https://github.com/fakekarash/AyuGram-iOS/actions/runs/38618649899),
  commit `536a6e6ff0498ca7baa9f125a46b52adc5e6575a`;
- job `baseline`: success, 50 мин 7 с; весь run: 50 мин 20 с;
- сборка исходного клиента: 48 мин 54 с;
- Artifact: `ayugram-baseline-ipa-3-1`, ID `11924037449`, 79 216 864 байта;
- Artifact не просрочен; GitHub указал срок хранения до
  `2026-10-21T19:41:01Z`;
- SHA256 ZIP Artifact:
  `1a992c5b0375e3ab71b5bbce066352433acb11d9dffdc3a2a461c9f102de7ec6`.

Artifact скачан и проверен локально. Его SHA256 совпал с digest GitHub, CRC ZIP
исправен. В архиве ровно два файла:

| Файл | Размер |
| --- | ---: |
| `Telegram.ipa` | 79 214 237 байт |
| `manifest.json` | 2 371 байт |

`Telegram.ipa` также проходит полную CRC-проверку. SHA256 IPA
`27d7cf5b7b51f0e7ea89a54cc08c2f1b3d390c65a45af3a2f2a628f859136bfc`
совпадает со значением в `manifest.json`; размер тоже совпадает. Проверены
`CFBundleIdentifier=ph.telegra.Telegraph`, платформа `iPhoneOS`, непустой Mach-O
исполняемый файл и ARM64 через `lipo` на runner. В IPA находятся шесть штатных
расширений: Share, NotificationContent, NotificationService, Intents, Widget и
BroadcastUpload.

Это **re-signable baseline IPA исходного Telegram**, собранная с публичными
upstream fake-профилями. Перед установкой её требуется переподписать. Установка,
запуск, авторизация, push-уведомления и refresh на реальном iPhone не проверялись.
Ghost Mode, Anti-Recall и другие функции AyuGram не добавлялись.

## История smoke-запусков

1. [Run №1](https://github.com/fakekarash/AyuGram-iOS/actions/runs/38464997255)
   завершился ошибкой до компиляции: повторный импорт публичного сертификата
   приводил к `SecKeychainItemImport: The specified item already exists`.
   Artifact отсутствует.
2. [Run №2](https://github.com/fakekarash/AyuGram-iOS/actions/runs/38465563318)
   полностью собрал клиент, но упал в проверке из-за порядка аргументов `lipo`
   в Xcode 26.6. Artifact отсутствует.
3. Run №3 после минимального исправления валидатора успешно собрал, проверил и
   загрузил IPA. Логи показывают ровно два загруженных файла и тот же digest,
   который получен при локальной проверке скачанного Artifact.

## Состояние репозитория

- Локальная ветка: `master`; локальный HEAD не менялся:
  `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`.
- Локальная ветка не коммитилась и не сбрасывалась. Существовавшие изменения
  пользователя сохранены.
- `origin` остаётся `https://github.com/TelegramMessenger/Telegram-iOS.git`.
- Добавлен remote `fork`: `https://github.com/fakekarash/AyuGram-iOS.git`.
- Проверенная baseline-сборка создана с commit
  `536a6e6ff0498ca7baa9f125a46b52adc5e6575a`; последующие commits меняют только
  этот итоговый отчёт.
- Для репозитория установлен `core.longpaths=true`.
- Все 13 рекурсивных подмодулей инициализированы, стоят на gitlink-коммитах и
  имеют чистый status:

| Подмодуль | Commit |
| --- | --- |
| `build-system/bazel-rules/apple_support` | `872de7149cfbcaaf854c7867e98b6d4798ba0d27` |
| `build-system/bazel-rules/rules_apple` | `485016eb5b0948cc17307064e7977a6d68e94046` |
| `build-system/bazel-rules/rules_swift` | `dd10a2497a691237eb9716586acee1a9c4fe3e59` |
| `build-system/bazel-rules/rules_xcodeproj` | `f6a54168d19f917d0630e7d4efa8f2f9fa0ddc36` |
| `submodules/TgVoipWebrtc/tgcalls` | `a024eaabf13c189d9577a14fb244bd242825ac96` |
| `submodules/rlottie/rlottie` | `53c9679069eb6b6513ccc3c892ef4f4a760658da` |
| `submodules/tlottie/tlottie` | `31f1b542f88e7b4be9a01e749920d857535fc715` |
| `third-party/dav1d/dav1d` | `330e20672e85f9de1678dccd6957845898ef57a1` |
| `third-party/libvpx/libvpx` | `e7bfd8b6c230a6824e7fd1efa2378a7322986128` |
| `third-party/mtproto-engine` | `0de759a36cbb50c1e98560c1ffa38590d317b0fc` |
| `third-party/td/td` | `e894536b2f46caad93f997448d2daff9431b19dd` |
| `third-party/wallet-engine/wallet-engine` | `e59e0d89d7ee90c388bf36e3334c5b276f396697` |
| `third-party/webrtc/webrtc` | `6513c71d6c80311d69a0a6b9c09fcf32cfbeb247` |

## Локальные файлы

Изменения, которые существовали до baseline-аудита и не перезаписывались:

- `.gitignore` — modified;
- `.github/workflows/ayugram-smoke-ipa.yml` — untracked;
- `build-system/ayugram-development-configuration.example.json` — untracked;
- `docs/AYUGRAM_WINDOWS_CI.md` — untracked.

Добавленные для baseline smoke-сборки файлы:

- `.github/workflows/ayugram-baseline-ipa.yml`;
- `build-system/ayugram_ci.py`;
- `docs/AYUGRAM_BASELINE_AUDIT.md`.

Новый workflow и helper опубликованы в форке отдельными web-коммитами. Локальный
индекс и локальный HEAD при этом не изменялись.

## Закреплённое окружение

| Компонент | Требование / фактическое значение run №3 |
| --- | --- |
| Runner | `macos-26`, ARM64 |
| macOS | major 26; фактически `26.6.2` |
| Xcode | `26.6`; фактически `Xcode 26.6`, build `17F113` |
| `deploy_xcode` | `26.2` — отдельное поле `versions.json` |
| Bazel | `9.2.0`, `darwin-arm64` |
| SHA256 Bazel | `dd466352a3e4d3581b8898740ee1ff208866ccbe25f8d367c5dcb950219587e6` |
| Telegram | версия `13.0`, `release_arm64` |

Workflow запускается только через `workflow_dispatch`, имеет
`permissions: contents: read`, не реагирует на push и не создаёт Release. Старый
workflow `CI` (`.github/workflows/build.yml`) отключён вручную. API GitHub
подтверждает состояние `disabled_manually`; в форке нет GitHub Releases.

## GitHub Secrets

Нужны ровно два Repository secrets с точными именами:

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`

Они уже созданы в форке через GitHub UI. Значения не записаны в репозиторий,
manifest или отчёт и не выводились в логи. Apple ID, пароль, код 2FA, личные
сертификаты и provisioning profiles не запрашивались и не сохранялись.

## Как запустить снова

1. Открыть репозиторий `fakekarash/AyuGram-iOS`.
2. Нажать **Actions**.
3. В списке выбрать **AyuGram iOS baseline IPA (manual)**.
4. Нажать **Run workflow**, оставить ветку `master` и ещё раз нажать
   **Run workflow**.
5. После зелёного завершения открыть run → **Artifacts** →
   `ayugram-baseline-ipa-<run_number>-<run_attempt>`.

Не запускать старый `CI`: он отключён из-за неподходящего `macos-13`, push-trigger
и автоматического Release.

## Ограничения AltStore, SideStore и Sideloadly

- Бесплатный Apple Account обычно требует повторной подписи каждые **7 дней**.
  Для Personal Team действуют лимиты до **10 App ID** за период и до **3
  установленных приложений** на устройстве.
- Основное приложение и шесть расширений потенциально занимают **7 App ID**.
  AltStore или SideStore также занимают слот приложения. Инструмент переподписи
  может удалить часть расширений, чтобы сэкономить App ID, но соответствующие
  функции перестанут работать.
- **AltStore Classic** требует доступного AltServer для установки и refresh по
  USB/Wi-Fi.
- **SideStore** требует pairing и корректного локального/VPN-соединения для
  refresh; лимиты бесплатного аккаунта сохраняются.
- **Sideloadly** выполняет повторную подпись с компьютера; auto-refresh зависит
  от работающего daemon и доступности устройства.
- Push/APNs нельзя считать работающими после простой переподписи. Нужны профиль
  с `aps-environment`, допустимый App ID/topic и серверная APNs-авторизация.
- App Groups, Keychain access groups, Associated Domains, iCloud, Siri и другие
  entitlement должны соответствовать новой подписи и provisioning profile.
  Их удаление или несовпадение может отключить расширения, общий контейнер,
  push и другие функции либо привести к ошибке установки.

## Проверено и не проверено

Фактически проверено: macOS/Xcode/Bazel, 13 подмодулей, полная компиляция baseline,
ZIP/IPA CRC, bundle ID, iPhoneOS platform, непустой executable, ARM64, шесть
расширений, SHA256 IPA, manifest, успешная загрузка и последующее скачивание
Artifact. Проверено отсутствие Releases и отключение старого workflow.

Не проверено: переподпись конкретной версией AltStore/SideStore/Sideloadly,
установка и запуск на iPhone, вход в Telegram, 7-дневный refresh, push/APNs и
поведение entitlement после переподписи. Эти пункты остаются отдельными
проверками на устройстве и не являются результатом текущего CI.
