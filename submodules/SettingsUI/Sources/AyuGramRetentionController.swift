import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private final class AyuGramRetentionArguments {
    let toggle: (String, Bool) -> Void
    let addRule: (AyuGramPeerRule) -> Void
    let cycleRule: (EnginePeer.Id) -> Void
    let cycleRetention: () -> Void
    let cycleLimit: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, addRule: @escaping (AyuGramPeerRule) -> Void, cycleRule: @escaping (EnginePeer.Id) -> Void, cycleRetention: @escaping () -> Void, cycleLimit: @escaping () -> Void) {
        self.toggle = toggle
        self.addRule = addRule
        self.cycleRule = cycleRule
        self.cycleRetention = cycleRetention
        self.cycleLimit = cycleLimit
    }
}

private final class AyuGramRetentionHolder {
    weak var controller: ItemListController?
}

private enum AyuGramRetentionSection: Int32 {
    case sources
    case content
    case rules
    case storage
    case notifications
}

private enum AyuGramRetentionEntry: ItemListNodeEntry {
    case header(Int32, String, AyuGramRetentionSection)
    case toggle(Int32, String, String, Bool, AyuGramRetentionSection)
    case action(Int32, String, String, AyuGramRetentionSection)
    case peer(Int32, EnginePeer, AyuGramPeerRule)
    case info(Int32, String, AyuGramRetentionSection)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, _, section), let .toggle(_, _, _, _, section), let .action(_, _, _, section), let .info(_, _, section):
            return section.rawValue
        case .peer:
            return AyuGramRetentionSection.rules.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .action(id, _, _, _), let .info(id, _, _), let .peer(id, _, _):
            return id
        }
    }

    static func < (lhs: AyuGramRetentionEntry, rhs: AyuGramRetentionEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramRetentionArguments
        switch self {
        case let .header(_, text, _):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, key, title, value, _):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { arguments.toggle(key, $0) })
        case let .action(_, key, title, _):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if key == "addAlways" {
                    arguments.addRule(.always)
                } else if key == "addNever" {
                    arguments.addRule(.never)
                } else if key == "retention" {
                    arguments.cycleRetention()
                } else if key == "limit" {
                    arguments.cycleLimit()
                }
            })
        case let .peer(_, peer, rule):
            let prefix = rule == .always ? "Всегда" : "Никогда"
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "\(prefix): \(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))", kind: rule == .never ? .destructive : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.cycleRule(peer.id) })
        case let .info(_, text, _):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayuGramRetentionEntries(peers: [EnginePeer.Id: EnginePeer]) -> [AyuGramRetentionEntry] {
    var entries: [AyuGramRetentionEntry] = [
        .header(0, "ИСТОЧНИКИ", .sources),
        .toggle(1, "private", "Личные чаты", AyuGramSettings.savePrivateChats, .sources),
        .toggle(2, "groups", "Группы и супергруппы", AyuGramSettings.saveGroups, .sources),
        .toggle(3, "channels", "Каналы", AyuGramSettings.saveChannels, .sources),
        .toggle(4, "bots", "Боты", AyuGramSettings.saveBots, .sources),
        .info(5, "Если все категории выключены, сохраняться будут только чаты из списка «Всегда». Индивидуальные правила имеют приоритет.", .sources),
        .header(20, "ЧТО СОХРАНЯТЬ", .content),
        .toggle(21, "text", "Удалённый текст", AyuGramSettings.saveDeletedText, .content),
        .toggle(22, "edits", "История изменений", AyuGramSettings.editHistoryEnabled, .content),
        .toggle(23, "photos", "Фотографии", AyuGramSettings.saveDeletedPhotos, .content),
        .toggle(24, "videos", "Видео и видеосообщения", AyuGramSettings.saveDeletedVideos, .content),
        .toggle(25, "voice", "Голосовые сообщения", AyuGramSettings.saveDeletedVoice, .content),
        .toggle(26, "files", "Файлы", AyuGramSettings.saveDeletedFiles, .content),
        .toggle(27, "stickers", "Стикеры и GIF", AyuGramSettings.saveDeletedStickers, .content),
        .toggle(28, "viewOnce", "Одноразовые фото и видео", AyuGramSettings.preserveViewOnceMedia, .content),
        .header(40, "ИНДИВИДУАЛЬНЫЕ ПРАВИЛА", .rules),
        .action(41, "addAlways", "Добавить в «Всегда сохранять»", .rules),
        .action(42, "addNever", "Добавить в «Никогда не сохранять»", .rules)
    ]

    let alwaysIds = AyuGramSettings.peerIds(rule: .always)
    let neverIds = AyuGramSettings.peerIds(rule: .never)
    var index: Int32 = 0
    for id in alwaysIds {
        if let peer = peers[id] {
            entries.append(.peer(100 + index, peer, .always))
            index += 1
        }
    }
    for id in neverIds {
        if let peer = peers[id] {
            entries.append(.peer(500 + index, peer, .never))
            index += 1
        }
    }
    entries.append(.info(900, "Нажатие на добавленный чат переключает: всегда → никогда → общие настройки.", .rules))

    let retentionText = AyuGramSettings.retentionDays == 0 ? "Без ограничения" : "\(AyuGramSettings.retentionDays) дней"
    let limitText = AyuGramSettings.vaultLimitMB == 0 ? "Без ограничения" : "\(AyuGramSettings.vaultLimitMB) МБ"
    entries.append(contentsOf: [
        .header(1000, "ХРАНИЛИЩЕ", .storage),
        .action(1001, "retention", "Срок хранения: \(retentionText)", .storage),
        .action(1002, "limit", "Лимит медиа: \(limitText)", .storage),
        .toggle(1003, "biometric", "Защищать хранилище Face ID", AyuGramSettings.vaultBiometricLockEnabled, .storage),
        .info(1004, "Лимит удаляет самые старые сохранённые файлы. Текстовый архив очищается по сроку хранения.", .storage),
        .header(1100, "УВЕДОМЛЕНИЯ ОБ УДАЛЕНИИ", .notifications),
        .toggle(1101, "noticePrivate", "Личные чаты", AyuGramSettings.notifyPrivateChats, .notifications),
        .toggle(1102, "noticeGroups", "Группы", AyuGramSettings.notifyGroups, .notifications),
        .toggle(1103, "noticeChannels", "Каналы", AyuGramSettings.notifyChannels, .notifications),
        .toggle(1104, "noticeBots", "Боты", AyuGramSettings.notifyBots, .notifications),
        .toggle(1105, "hideNotice", "Скрывать текст уведомления", AyuGramSettings.hideNotificationContent, .notifications),
        .info(1106, "Системное уведомление возможно, пока iOS позволяет sideload-приложению работать в фоне. После принудительного закрытия обновление придёт при следующем запуске.", .notifications)
    ])
    return entries
}

public func ayuGramRetentionController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let peersPromise = ValuePromise<[EnginePeer.Id: EnginePeer]>([:], ignoreRepeated: false)
    let holder = AyuGramRetentionHolder()

    let refresh: () -> Void = {
        let ids = Array(Set(AyuGramSettings.peerIds(rule: .always) + AyuGramSettings.peerIds(rule: .never)))
        let _ = (context.account.postbox.transaction { transaction -> [EnginePeer.Id: EnginePeer] in
            var result: [EnginePeer.Id: EnginePeer] = [:]
            for id in ids {
                if let peer = transaction.getPeer(id) {
                    result[id] = EnginePeer(peer)
                }
            }
            return result
        }
        |> deliverOnMainQueue).startStandalone(next: { peers in
            peersPromise.set(peers)
            revision.set(revisionValue.modify { $0 + 1 })
        })
    }

    let removePicker: (ViewController?) -> Void = { controller in
        guard let controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== controller }, animated: true)
    }

    let arguments = AyuGramRetentionArguments(toggle: { key, value in
        switch key {
        case "private": AyuGramSettings.savePrivateChats = value
        case "groups": AyuGramSettings.saveGroups = value
        case "channels": AyuGramSettings.saveChannels = value
        case "bots": AyuGramSettings.saveBots = value
        case "text": AyuGramSettings.saveDeletedText = value
        case "edits": AyuGramSettings.editHistoryEnabled = value
        case "photos": AyuGramSettings.saveDeletedPhotos = value
        case "videos": AyuGramSettings.saveDeletedVideos = value
        case "voice": AyuGramSettings.saveDeletedVoice = value
        case "files": AyuGramSettings.saveDeletedFiles = value
        case "stickers": AyuGramSettings.saveDeletedStickers = value
        case "viewOnce": AyuGramSettings.preserveViewOnceMedia = value
        case "biometric": AyuGramSettings.vaultBiometricLockEnabled = value
        case "noticePrivate": AyuGramSettings.notifyPrivateChats = value
        case "noticeGroups": AyuGramSettings.notifyGroups = value
        case "noticeChannels": AyuGramSettings.notifyChannels = value
        case "noticeBots": AyuGramSettings.notifyBots = value
        case "hideNotice": AyuGramSettings.hideNotificationContent = value
        default: break
        }
        revision.set(revisionValue.modify { $0 + 1 })
    }, addRule: { rule in
        let filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader, .excludeSecretChats]
        let title = rule == .always ? "Всегда сохранять" : "Никогда не сохранять"
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: title))
        controller.peerSelected = { [weak controller] peer, _ in
            AyuGramSettings.setPeerRule(rule, peerId: peer.id)
            removePicker(controller)
            refresh()
        }
        holder.controller?.push(controller)
    }, cycleRule: { peerId in
        switch AyuGramSettings.peerRule(peerId) {
        case .always: AyuGramSettings.setPeerRule(.never, peerId: peerId)
        case .never: AyuGramSettings.setPeerRule(.inherit, peerId: peerId)
        case .inherit: AyuGramSettings.setPeerRule(.always, peerId: peerId)
        }
        refresh()
    }, cycleRetention: {
        switch AyuGramSettings.retentionDays {
        case 0: AyuGramSettings.retentionDays = 7
        case 7: AyuGramSettings.retentionDays = 30
        case 30: AyuGramSettings.retentionDays = 90
        default: AyuGramSettings.retentionDays = 0
        }
        AyuGramVaultStore.performMaintenance()
        AyuGramArchiveStore.performMaintenance()
        revision.set(revisionValue.modify { $0 + 1 })
    }, cycleLimit: {
        switch AyuGramSettings.vaultLimitMB {
        case 0: AyuGramSettings.vaultLimitMB = 500
        case 500: AyuGramSettings.vaultLimitMB = 1024
        case 1024: AyuGramSettings.vaultLimitMB = 2048
        default: AyuGramSettings.vaultLimitMB = 0
        }
        AyuGramVaultStore.performMaintenance()
        revision.set(revisionValue.modify { $0 + 1 })
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get(), peersPromise.get())
    |> map { presentationData, _, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let itemPresentationData = ItemListPresentationData(presentationData)
        return (
            ItemListControllerState(presentationData: itemPresentationData, title: .text("Правила AyuGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramRetentionEntries(peers: peers), style: .blocks, animateChanges: true), arguments)
        )
    }

    let controller = ItemListController(context: context, state: signal)
    holder.controller = controller
    refresh()
    return controller
}
