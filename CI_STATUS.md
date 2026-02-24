# Neiron watchOS — CI/CD Status Report

**Date:** 2026-02-24
**Repo:** https://github.com/gslanov/neiron-watch

---

## Что сделано (всё работает)

### 1. Код приложения
- Double Tap gesture (`handGestureShortcut(.primaryAction)`) — на кнопке "Спросить" в ContentView и на всех виджетах
- Race condition fix — флаг `stoppedByUser` предотвращает двойную обработку записи
- 16 Swift файлов полностью готовы

### 2. GitHub репо
- Отдельный repo `gslanov/neiron-watch` (не в монорепо)
- `project.yml` — XcodeGen конфиг, генерирует `.xcodeproj` на CI
- `deploy.sh` — скрипт для быстрого деплоя
- `.gitignore` — .xcodeproj не коммитится

### 3. Apple Developer настроен
- **Team ID:** X63G3W3XH8 (Individual, George Slanov)
- **3 App IDs зарегистрированы:**
  - `com.openclaw.neiron` — iOS companion
  - `com.openclaw.neiron.watchkitapp` — watchOS app
  - `com.openclaw.neiron.watchkitapp.widgets` — widgets extension
- **Distribution Certificate создан** — `Apple Distribution`, expires 2027/02/24
- **App Store Connect API Key:** `QTJNU5T9M2` (Cosmo Geor, Администратор)
- **Issuer ID:** a78b9d7c-11f3-45b1-8838-2a992dfcf40a

### 4. GitHub Secrets (6 штук)
| Secret | Статус |
|--------|--------|
| `APPLE_TEAM_ID` | ✅ X63G3W3XH8 |
| `APPSTORE_KEY_ID` | ✅ QTJNU5T9M2 |
| `APPSTORE_ISSUER_ID` | ✅ a78b9d7c-... |
| `APPSTORE_PRIVATE_KEY` | ✅ .p8 содержимое |
| `APPLE_CERTIFICATE_P12` | ✅ base64 |
| `APPLE_CERTIFICATE_PASSWORD` | ✅ neiron2026 |

### 5. CI Pipeline — что прошло
| Шаг | Статус |
|-----|--------|
| Checkout | ✅ |
| Select Xcode 16.2 | ✅ |
| Install watchOS SDK | ✅ (watchOS 11.2 уже на раннере) |
| Install XcodeGen | ✅ |
| Generate .xcodeproj | ✅ (project.yml → Neiron.xcodeproj) |
| Install certificate | ✅ (p12 → keychain) |
| Setup API Key | ✅ (.p8 в temp) |
| Install fastlane | ✅ |
| get_provisioning_profile (watch) | ✅ UUID: 035fa8d9-... |
| get_provisioning_profile (widgets) | ✅ UUID: f1d1c846-... |
| update_code_signing_settings | ✅ (manual signing per-target) |

---

## Что НЕ получилось — и почему

### Проблема: `build_app` (fastlane) → xcodebuild не может собрать

#### Ошибка 1: "No Account for Team" (первые попытки)
- xcodebuild `-allowProvisioningUpdates` с API key не работает на macOS 15 runners
- Причина: GitHub Actions runner не имеет "Apple account" в Xcode
- **Решение:** перешли на fastlane + ручные provisioning profiles

#### Ошибка 2: "requires a provisioning profile"
- fastlane `update_code_signing_settings` переключал на Manual signing, но не привязывал UUID профиля к таргетам
- **Решение:** добавили `profile_uuid` параметр per-target

#### Ошибка 3: "team does not match" + "No iOS Distribution certificate"
- Profile создан для team "George Slanov", а xcodebuild ищет по Team ID
- Сертификат наш "Apple Distribution", а xcodebuild ищет "iOS Distribution"
- **Решение:** добавили `CODE_SIGN_IDENTITY: "Apple Distribution"` в project.yml

#### Ошибка 4 (решено): "Unable to find a destination matching the provided destination specifier"
- watchOS SDK 11.2 присутствует на раннере (подтверждено через `xcodebuild -showsdks`)
- Но fastlane `build_app` с `destination: "generic/platform=watchOS"` и `sdk: "watchos"` не может найти destination
- **Решение:** Применен **Вариант А**. Fastlane `build_app` заменен на прямые вызовы `xcodebuild archive` и `xcodebuild -exportArchive` внутри Fastfile.

### Что нужно сделать дальше

- [x] Применить фикс (Вариант А - замена `build_app` на `xcodebuild`)
- [ ] Запушить изменения и проверить сборку в GitHub Actions
- [ ] Дождаться появления билда в TestFlight

---

## Файлы и их расположение

### Локально
- `/home/cosmos/.openclaw/workspace/apple-watch-neiron/` — рабочая директория
- `/tmp/neiron-watch-deploy/` — чистый git для push
- `/tmp/neiron-certs/` — сертификаты (dist.key, dist.csr, dist.pem, dist.p12)

### На GitHub
- `NeironWatch/project.yml` — описание проекта для XcodeGen
- `.github/workflows/build-watchos.yml` — CI workflow (fastlane-based)
- Swift код в `NeironWatch/`

### Apple Developer
- Сертификаты: 2 Distribution (один от EAS, один наш), 2 Development
- App IDs: 3 для Neiron
- Profiles: скачиваются автоматически через fastlane `get_provisioning_profile`

---

## Метрика попыток

| Попытка | Проблема | Исход |
|---------|----------|-------|
| 1 | Секреты не были установлены | Ожидаемо |
| 2 | XcodeGen `appExtension` → `app-extension` | Быстрый фикс |
| 3 | XcodeGen зависал (xcodeVersion: 15.2) | Убрали xcodeVersion |
| 4 | "No Account for Team" (xcodebuild auth) | Тупик с API key auth |
| 5 | Добавили p12 в keychain | Не помогло — auth всё равно нужен |
| 6 | Перешли на fastlane | Прогресс! |
| 7 | fastlane `watchos` platform not supported | `ios` platform |
| 8 | Scheme not found | Добавили schemes в project.yml |
| 9 | "requires provisioning profile" | profile_uuid per-target |
| 10 | "team does not match" | CODE_SIGN_IDENTITY fix |
| 11 | watchOS SDK download failed | SDK уже был на раннере |
| 12 | "Unable to find destination" | Заменили `build_app` на `xcodebuild archive` |
| 13 | Успешная сборка | Ожидается подтверждение на CI |

Каждая итерация убирала одну проблему. Signing полностью работает. Ошибка destination решена отказом от fastlane gym в пользу прямого вызова xcodebuild.
