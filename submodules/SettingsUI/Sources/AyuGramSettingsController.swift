import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private final class AyuGramSettingsControllerArguments {
    let update: (AyuGramSetting, Bool) -> Void
    let openUrl: (String) -> Void

    init(update: @escaping (AyuGramSetting, Bool) -> Void, openUrl: @escaping (String) -> Void) {
        self.update = update
        self.openUrl = openUrl
    }
}

private enum AyuGramSetting {
    case ghostModeEnabled
    case hideReadReceipts
    case hideStoryViews
    case hideTyping
    case stayOffline
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
    var saveRestrictedContent = AyuGramSettings.saveRestrictedContent
    var preserveViewOnceMedia = AyuGramSettings.preserveViewOnceMedia
    var vaultEnabled = AyuGramSettings.vaultEnabled
}

private enum AyuGramSettingsSection: Int32 {
    case ghost
    case privacy
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
    case mediaHeader
    case restricted(Bool)
    case viewOnce(Bool)
    case vault(Bool)
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
        case .mediaHeader, .restricted, .viewOnce, .vault, .mediaFooter:
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
        case .mediaHeader: return 8
        case .restricted: return 9
        case .viewOnce: return 10
        case .vault: return 11
        case .mediaFooter: return 12
        case .linksHeader: return 13
        case .github: return 14
        case .telegram: return 15
        case .version: return 16
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
        case .mediaHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МЕДИА", sectionId: self.section)
        case let .restricted(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять защищённый контент", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.saveRestrictedContent, $0) })
        case let .viewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не удалять одноразовые медиа", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.preserveViewOnceMedia, $0) })
        case let .vault(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Локальное хранилище AyuGram", value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.vaultEnabled, $0) })
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
        .mediaHeader,
        .restricted(settings.saveRestrictedContent),
        .viewOnce(settings.preserveViewOnceMedia),
        .vault(settings.vaultEnabled),
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

    let arguments = AyuGramSettingsControllerArguments(update: { keyPath, value in
        switch keyPath {
        case .ghostModeEnabled: AyuGramSettings.ghostModeEnabled = value
        case .hideReadReceipts: AyuGramSettings.hideReadReceiptsOption = value
        case .hideStoryViews: AyuGramSettings.hideStoryViewsOption = value
        case .hideTyping: AyuGramSettings.hideTypingOption = value
        case .stayOffline: AyuGramSettings.stayOfflineOption = value
        case .saveRestrictedContent: AyuGramSettings.saveRestrictedContent = value
        case .preserveViewOnceMedia: AyuGramSettings.preserveViewOnceMedia = value
        case .vaultEnabled: AyuGramSettings.vaultEnabled = value
        }
        revision.set(revisionValue.modify { value in
            return value + 1
        })
    }, openUrl: { url in
        context.sharedContext.applicationBindings.openUrl(url)
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
    controller.navigationPresentation = .modal
    return controller
}
