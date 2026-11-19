import Foundation

public struct AyuGramStrings {
    public let isRussian: Bool

    public init(languageCode: String) {
        let code = languageCode.lowercased()
        self.isRussian = code.hasPrefix("ru") || code.hasPrefix("uk") || code.hasPrefix("be") || code.hasPrefix("kk") || code.hasPrefix("ky")
    }

    private func localized(_ russian: String, _ english: String) -> String {
        return self.isRussian ? russian : english
    }

    public var appName: String { "AyuGram" }
    public var categories: String { self.localized("КАТЕГОРИИ", "CATEGORIES") }
    public var links: String { self.localized("ССЫЛКИ", "LINKS") }
    public var versionFooter: String { self.localized("AyuGram iOS", "AyuGram iOS") }

    public var ghostMode: String { self.localized("Режим Призрака", "Ghost Mode") }
    public var ghostModeSubtitle: String { self.localized("Скрыть прочтение, набор и онлайн", "Hide reads, typing and online") }
    public var spy: String { self.localized("Шпион", "Spy") }
    public var spySubtitle: String { self.localized("Удалённые сообщения и история", "Deleted messages and history") }
    public var filters: String { self.localized("Фильтры", "Filters") }
    public var filtersSubtitle: String { self.localized("Чаты, типы контента, хранение", "Chats, content types, storage") }

    public var channel: String { self.localized("Канал", "Channel") }
    public var chats: String { self.localized("Чаты", "Chats") }
    public var translation: String { self.localized("Перевод", "Translation") }
    public var github: String { self.localized("GitHub проекта", "Project GitHub") }
    public var version: String { self.localized("Версия", "Version") }
    public var notAvailable: String { self.localized("Скоро", "Soon") }

    public var ghostHeader: String { self.localized("ПРИЗРАК", "GHOST MODE") }
    public var ghostMaster: String { self.localized("Включить Режим Призрака", "Enable Ghost Mode") }
    public var hideReads: String { self.localized("Не отправлять прочтение", "Do not send read receipts") }
    public var hideStories: String { self.localized("Скрывать просмотры историй", "Hide story views") }
    public var hideTyping: String { self.localized("Скрывать набор текста", "Hide typing") }
    public var stayOffline: String { self.localized("Всегда офлайн", "Always offline") }
    public var ghostFooter: String {
        self.localized("Прочтение и просмотры остаются только на этом устройстве. Отдельные функции применяются, пока режим включён.",
                       "Reads and views stay on this device only. The individual switches apply while the mode is enabled.")
    }

    public var spyHeader: String { self.localized("УДАЛЕНИЕ И РЕДАКТИРОВАНИЕ", "DELETION AND EDITS") }
    public var antiRecall: String { self.localized("Сохранять удалённые сообщения", "Keep deleted messages") }
    public var editHistory: String { self.localized("История редактирования", "Edit history") }
    public var deletedMarker: String { self.localized("Помечать удалённые сообщения", "Mark deleted messages") }
    public var deletionNotices: String { self.localized("Уведомлять об удалении", "Notify about deletions") }
    public var systemNotices: String { self.localized("Системные уведомления", "System notifications") }
    public var opacity: String { self.localized("Видимость удалённых", "Deleted message opacity") }
    public var spyFooter: String {
        self.localized("Сохраняются только сообщения, которые это устройство уже получило. История изменений доступна по долгому нажатию на сообщение.",
                       "Only messages this device has already received are kept. Edit history is available on message long-press.")
    }

    public var mediaHeader: String { self.localized("МЕДИА", "MEDIA") }
    public var restricted: String { self.localized("Сохранять защищённый контент", "Allow saving protected content") }
    public var viewOnce: String { self.localized("Сохранять одноразовые медиа", "Keep view-once media") }
    public var vault: String { self.localized("Локальное хранилище", "Local vault") }
    public var openVault: String { self.localized("Открыть хранилище", "Open vault") }
    public var vaultLock: String { self.localized("Защищать хранилище", "Protect vault") }
    public var mediaFooter: String {
        self.localized("AyuGram сохраняет одноразовые и удалённые вложения в защищённую папку внутри приложения.",
                       "AyuGram stores view-once and deleted attachments in a protected folder inside the app.")
    }

    public var biometricTitle: String { "AyuGram" }
    public var biometricReason: String { self.localized("Открыть хранилище AyuGram", "Unlock the AyuGram vault") }
    public var biometricUnavailable: String {
        self.localized("Face ID или Touch ID недоступны. Отключите защиту хранилища в AyuGram.",
                       "Face ID or Touch ID is unavailable. Disable vault protection in AyuGram.")
    }
}
