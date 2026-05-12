# Media Player Showcase

Публичный portfolio snapshot iOS-медиаплеера. Репозиторий оставлен как демонстрация архитектуры, UI-слоя и работы с медиа, но не является полной сборочной копией коммерческого приложения.

## Статус репозитория

Это намеренно неполная showcase-версия:

- удалены история Git, Pods, workspace, ассеты, шрифты, StoreKit-конфигурация и production-настройки;
- удалены Xcode project, app entrypoint, Info.plist, entitlements и launch storyboard;
- реальные product id, bundle id, ссылки поддержки и брендовые строки заменены на нейтральные placeholder-значения;
- подписка переведена в development-disabled режим;
- проект нельзя использовать для восстановления исходного продукта без заново созданных ассетов, зависимостей, конфигов, подписок и сборочной инфраструктуры.

## Что демонстрирует проект

- UIKit-приложение с кастомной навигацией, вкладками, полноэкранным плеером, paywall/onboarding экранами и отдельными адаптациями для iPhone/iPad.
- Воспроизведение аудио и видео через AVPlayer, а для расширенных форматов - интеграция с VLC-движком.
- Подготовка Picture in Picture для неподдерживаемых контейнеров через FFmpeg pipeline: remux, fallback transcode, проверка готового MP4 через AVFoundation, прогресс конвертации.
- Локальное хранение медиатеки: видео, аудио, плейлисты, альбомы, папки, recent-элементы, прогресс воспроизведения и PiP-кэш.
- Фоновое аудио, Now Playing metadata, remote commands и восстановление состояния воспроизведения.
- StoreKit-слой для подписок, восстановления покупок и graceful fallback между StoreKit 2 и StoreKit 1.
- Ручная локализация на RU, EN, FR, PT, ES, DE через `.lproj` и runtime-переключение языка.
- Работа с системными возможностями iOS: Files/Photo Library import, MessageUI, SKStoreReviewController, AVAudioSession, security-scoped resources.

## Структура

- `Player/Views` - UIKit-экраны, табы, плеер, paywall, onboarding, настройки.
- `Player/Presenters` - связующий слой между view и сервисами.
- `Player/Services` - playback, storage, metadata, covers, PiP conversion, subscriptions, Now Playing.
- `Player/Models` - медиамодели, плейлисты, альбомы, папки, режимы воспроизведения.
- `Player/Helpers` - локализация, адаптивные размеры, typography, цвета, reusable UI helpers.
- `Player/*.lproj` - локализованные строки.

## Файлы, которые лучше смотреть в первую очередь

- `Player/Services/PlayerService.swift` - единый playback service с AVPlayer/VLC, очередью, прогрессом, восстановлением и обработкой ошибок.
- `Player/Services/PiPConversionService.swift` - pipeline подготовки MP4 для Picture in Picture.
- `Player/Services/MediaStorageService.swift` - локальное хранение библиотеки, прогресса, PiP-кэша и пользовательских коллекций.
- `Player/Views/PlayerViewController.swift` - сложный экран плеера с жестами, controls, PiP и состояниями playback.
- `Player/Services/NowPlayingService.swift` - интеграция с системным Now Playing и remote commands.
- `Player/Services/SubscriptionStore.swift` - StoreKit 2 / StoreKit 1 слой подписок.
- `Player/Helpers/AppStrings.swift` - runtime-локализация с выбором языка.
- `Player/Views/AudioTabViewController.swift` и `Player/Views/VideoTabViewController.swift` - адаптивные медиатабы.

## Ограничения showcase-версии

Репозиторий не предназначен для запуска через `pod install` или публикации в App Store. Он показывает инженерные решения и структуру, но runtime-зависимости, Xcode project и приватные материалы удалены намеренно. Это source showcase, а не запускаемое приложение.

