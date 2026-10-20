import Foundation
import UIKit
import LocalAuthentication
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import UserNotifications

private final class AyuGramSettingsControllerArguments {
    let update: (AyuGramSetting, Bool) -> Void
    let openUrl: (String) -> Void
    let openVault: () -> Void
    let openRetention: () -> Void
    let cycleDeletedOpacity: () -> Void

    init(
        update: @escaping (AyuGramSetting, Bool) -> Void,
        openUrl: @escaping (String) -> Void,
        openVault: @escaping () -> Void,
        openRetention: @escaping () -> Void,
        cycleDeletedOpacity: @escaping () -> Void
    ) {
        self.update = update
        self.openUrl = openUrl
        self.openVault = openVault
        self.openRetention = openRetention
        self.cycleDeletedOpacity = cycleDeletedOpacity
    }
}

private final class AyuGramSettingsControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramSetting {
    case ghostModeEnabled
    case hideReadReceipts
    case hideStoryViews
    case hideTyping
    case stayOffline
    case antiRecallEnabled
    case editHistoryEnabled
    case showDeletedMessageMarker
    case deletionNotificationsEnabled
    case systemDeletionNotificationsEnabled
    case saveRestrictedContent
    case preserveViewOnceMedia
    case vaultEnabled
}

private struct AyuGramSettingsProxy {
    var ghostModeEnabled = AyuGramSettings.ghostModeEnabled
    var hideReadReceipts = AyuGramSettings.hideReadReceiptsOption
    var hideStoryViews = AyuGramSettings.hideStoryViewsOption
    var hideTyping = AyuGramSettings.hideTypingOption
    var stayOffline = AyuGramSettings.stayOfflineOption
    var antiRecallEnabled = AyuGramSettings.antiRecallEnabled
    var editHistoryEnabled = AyuGramSettings.editHistoryEnabled
    var showDeletedMessageMarker = AyuGramSettings.showDeletedMessageMarker
    var deletionNotificationsEnabled = AyuGramSettings.deletionNotificationsEnabled
    var systemDeletionNotificationsEnabled = AyuGramSettings.systemDeletionNotificationsEnabled
    var deletedMessageOpacity = AyuGramSettings.deletedMessageOpacity
    var saveRestrictedContent = AyuGramSettings.saveRestrictedContent
    var preserveViewOnceMedia = AyuGramSettings.preserveViewOnceMedia
    var vaultEnabled = AyuGramSettings.vaultEnabled
}

private enum AyuGramSettingsSection: Int32 {
    case ghost
    case privacy
    case antiRecall
    case media
    case links
}

private enum AyuGramSettingsEntry: ItemListNodeEntry {
    case ghostHeader
    case ghost(Bool)
    case ghostFooter
    case privacyHeader
    case readReceipts(Bool)
    case storyViews(Bool)
    case typing(Bool)
    case offline(Bool)
    case antiRecallHeader
    case antiRecall(Bool)
    case editHistory(Bool)
    case deletedMarker(Bool)
    case deletionNotifications(Bool)
    case systemDeletionNotifications(Bool)
    case deletedOpacity(Int)
    case retentionRules
    case antiRecallFooter
    case mediaHeader
    case restricted(Bool)
    case viewOnce(Bool)
    case vault(Bool)
    case openVault(String)
    case mediaFooter
    case linksHeader
    case github
    case telegram
    case version(String)

    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghost, .ghostFooter:
            return AyuGramSettingsSection.ghost.rawValue
        case .privacyHeader, .readReceipts, .storyViews, .typing, .offline:
            return AyuGramSettingsSection.privacy.rawValue
        case .antiRecallHeader, .antiRecall, .editHistory, .deletedMarker, .deletionNotifications, .systemDeletionNotifications, .deletedOpacity, .retentionRules, .antiRecallFooter:
            return AyuGramSettingsSection.antiRecall.rawValue
        case .mediaHeader, .restricted, .viewOnce, .vault, .openVault, .mediaFooter:
            return AyuGramSettingsSection.media.rawValue
        case .linksHeader, .github, .telegram, .version:
            return AyuGramSettingsSection.links.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ghostHeader: return 0
        case .ghost: return 1
        case .ghostFooter: return 2
        case .privacyHeader: return 3
        case .readReceipts: return 4
        case .storyViews: return 5
        case .typing: return 6
        case .offline: return 7
        case .antiRecallHeader: return 8
        case .antiRecall: return 9
        case .editHistory: return 10
        case .deletedMarker: return 11
        case .deletionNotifications: return 12
        case .systemDeletionNotifications: return 13
        case .deletedOpacity: return 14
        case .retentionRules: return 15
        case .antiRecallFooter: return 16
        case .mediaHeader: return 17
        case .restricted: return 18
        case .viewOnce: return 19
        case .vault: return 20
        case .openVault: return 21
        case .mediaFooter: return 22
        case .linksHeader: return 23
        case .github: return 24
        case .telegram: return 25
        case .version: return 26
        }
    }

    static func < (lhs: AyuGramSettingsEntry, rhs: AyuGramSettingsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramSettingsControllerArguments
        switch self {
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "GHOST MODE", sectionId: self.section)
        case let .ghost(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Включить Ghost Mode", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.ghostModeEnabled, $0) })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Сообщения остаются прочитанными только на этом устройстве. Отдельные функции можно настроить ниже."), sectionId: self.section)
        case .privacyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПРИВАТНОСТЬ", sectionId: self.section)
        case let .readReceipts(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не отправлять прочтение", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.hideReadReceipts, $0) })
        case let .storyViews(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать просмотры историй", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.hideStoryViews, $0) })
        case let .typing(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Скрывать набор текста", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.hideTyping, $0) })
        case let .offline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Всегда офлайн", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.stayOffline, $0) })
        case .antiRecallHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ANTI-RECALL", sectionId: self.section)
        case let .antiRecall(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.antiRecallEnabled, $0) })
        case let .editHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "История редактирования", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.editHistoryEnabled, $0) })
        case let .deletedMarker(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Помечать удалённые сообщения", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.showDeletedMessageMarker, $0) })
        case let .deletionNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Уведомлять об удалении", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.deletionNotificationsEnabled, $0) })
        case let .systemDeletionNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Системные уведомления", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.systemDeletionNotificationsEnabled, $0) })
        case let .deletedOpacity(value):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Видимость удалённых: \(value)%", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.cycleDeletedOpacity)
        case .retentionRules:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Источники, исключения и уведомления", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.openRetention)
        case .antiRecallFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("AyuGram сохраняет сообщения, которые уже были получены этим устройством. Предыдущие версии доступны по долгому нажатию на сообщение."), sectionId: self.section)
        case .mediaHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МЕДИА", sectionId: self.section)
        case let .restricted(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять защищённый контент", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.saveRestrictedContent, $0) })
        case let .viewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не удалять одноразовые медиа", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.preserveViewOnceMedia, $0) })
        case let .vault(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Локальное хранилище AyuGram", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.vaultEnabled, $0) })
        case let .openVault(value):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Открыть хранилище (\(value))", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.openVault)
        case .mediaFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Открытые одноразовые фото, видео и голосовые сообщения копируются в папку AyuGram Vault внутри приложения."), sectionId: self.section)
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "AYUGRAM IOS", sectionId: self.section)
        case .github:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "GitHub проекта", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.openUrl("https://github.com/fakekarash/AyuGram-iOS") })
        case .telegram:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Telegram-канал", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.openUrl("https://t.me/neAyuGramipa") })
        case let .version(value):
            return ItemListTextItem(presentationData: presentationData, text: .plain(value), sectionId: self.section)
        }
    }
}

private func ayuGramSettingsEntries() -> [AyuGramSettingsEntry] {
    let settings = AyuGramSettingsProxy()
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    return [
        .ghostHeader,
        .ghost(settings.ghostModeEnabled),
        .ghostFooter,
        .privacyHeader,
        .readReceipts(settings.hideReadReceipts),
        .storyViews(settings.hideStoryViews),
        .typing(settings.hideTyping),
        .offline(settings.stayOffline),
        .antiRecallHeader,
        .antiRecall(settings.antiRecallEnabled),
        .editHistory(settings.editHistoryEnabled),
        .deletedMarker(settings.showDeletedMessageMarker),
        .deletionNotifications(settings.deletionNotificationsEnabled),
        .systemDeletionNotifications(settings.systemDeletionNotificationsEnabled),
        .deletedOpacity(Int((settings.deletedMessageOpacity * 100.0).rounded())),
        .retentionRules,
        .antiRecallFooter,
        .mediaHeader,
        .restricted(settings.saveRestrictedContent),
        .viewOnce(settings.preserveViewOnceMedia),
        .vault(settings.vaultEnabled),
        .openVault("\(AyuGramVaultStore.items().count + AyuGramArchiveStore.records().count)"),
        .mediaFooter,
        .linksHeader,
        .github,
        .telegram,
        .version("AyuGram iOS " + version)
    ]
}

public func ayuGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let controllerHolder = AyuGramSettingsControllerHolder()

    let refresh: () -> Void = {
        revision.set(revisionValue.modify { value in
            return value + 1
        })
    }

    let arguments = AyuGramSettingsControllerArguments(update: { keyPath, value in
        switch keyPath {
        case .ghostModeEnabled: AyuGramSettings.ghostModeEnabled = value
        case .hideReadReceipts: AyuGramSettings.hideReadReceiptsOption = value
        case .hideStoryViews: AyuGramSettings.hideStoryViewsOption = value
        case .hideTyping: AyuGramSettings.hideTypingOption = value
        case .stayOffline: AyuGramSettings.stayOfflineOption = value
        case .antiRecallEnabled: AyuGramSettings.antiRecallEnabled = value
        case .editHistoryEnabled: AyuGramSettings.editHistoryEnabled = value
        case .showDeletedMessageMarker: AyuGramSettings.showDeletedMessageMarker = value
        case .deletionNotificationsEnabled: AyuGramSettings.deletionNotificationsEnabled = value
        case .systemDeletionNotificationsEnabled:
            AyuGramSettings.systemDeletionNotificationsEnabled = value
            if value {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if !granted {
                        AyuGramSettings.systemDeletionNotificationsEnabled = false
                        DispatchQueue.main.async {
                            refresh()
                        }
                    }
                }
            }
        case .saveRestrictedContent: AyuGramSettings.saveRestrictedContent = value
        case .preserveViewOnceMedia: AyuGramSettings.preserveViewOnceMedia = value
        case .vaultEnabled: AyuGramSettings.vaultEnabled = value
        }
        refresh()
    }, openUrl: { url in
        context.sharedContext.applicationBindings.openUrl(url)
    }, openVault: {
        let open: () -> Void = {
            controllerHolder.controller?.push(ayuGramVaultController(context: context))
        }
        guard AyuGramSettings.vaultBiometricLockEnabled else {
            open()
            return
        }
        let authentication = LAContext()
        var error: NSError?
        guard authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let alert = UIAlertController(title: "AyuGram", message: "Face ID или Touch ID недоступны. Отключите защиту хранилища в правилах AyuGram.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            controllerHolder.controller?.present(alert, animated: true)
            return
        }
        authentication.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Открыть хранилище AyuGram") { success, _ in
            if success {
                DispatchQueue.main.async(execute: open)
            }
        }
    }, openRetention: {
        controllerHolder.controller?.push(ayuGramRetentionController(context: context))
    }, cycleDeletedOpacity: {
        let current = AyuGramSettings.deletedMessageOpacity
        if current < 0.475 {
            AyuGramSettings.deletedMessageOpacity = 0.55
        } else if current < 0.625 {
            AyuGramSettings.deletedMessageOpacity = 0.70
        } else {
            AyuGramSettings.deletedMessageOpacity = 0.40
        }
        refresh()
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: itemPresentationData, title: .text("AyuGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramSettingsEntries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerHolder.controller = controller
    controller.navigationPresentation = .modal
    return controller
}
