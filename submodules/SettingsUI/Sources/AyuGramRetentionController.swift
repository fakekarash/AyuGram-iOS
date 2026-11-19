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
            let prefix = rule == .always ? "Р’СЃРµРіРґР°" : "РќРёРєРѕРіРґР°"
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "\(prefix): \(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))", kind: rule == .never ? .destructive : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { arguments.cycleRule(peer.id) })
        case let .info(_, text, _):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayuGramRetentionEntries(peers: [EnginePeer.Id: EnginePeer]) -> [AyuGramRetentionEntry] {
    var entries: [AyuGramRetentionEntry] = [
        .header(0, "РРЎРўРћР§РќРРљР", .sources),
        .toggle(1, "private", "Р›РёС‡РЅС‹Рµ С‡Р°С‚С‹", AyuGramSettings.savePrivateChats, .sources),
        .toggle(2, "groups", "Р“СЂСѓРїРїС‹ Рё СЃСѓРїРµСЂРіСЂСѓРїРїС‹", AyuGramSettings.saveGroups, .sources),
        .toggle(3, "channels", "РљР°РЅР°Р»С‹", AyuGramSettings.saveChannels, .sources),
        .toggle(4, "bots", "Р‘РѕС‚С‹", AyuGramSettings.saveBots, .sources),
        .toggle(6, "publicChannels", "…в открытых каналах", AyuGramSettings.savePublicChannels, .sources),
        .toggle(7, "publicGroups", "…в открытых группах", AyuGramSettings.savePublicGroups, .sources),
        .info(5, "Р•СЃР»Рё РІСЃРµ РєР°С‚РµРіРѕСЂРёРё РІС‹РєР»СЋС‡РµРЅС‹, СЃРѕС…СЂР°РЅСЏС‚СЊСЃСЏ Р±СѓРґСѓС‚ С‚РѕР»СЊРєРѕ С‡Р°С‚С‹ РёР· СЃРїРёСЃРєР° В«Р’СЃРµРіРґР°В». РРЅРґРёРІРёРґСѓР°Р»СЊРЅС‹Рµ РїСЂР°РІРёР»Р° РёРјРµСЋС‚ РїСЂРёРѕСЂРёС‚РµС‚.", .sources),
        .header(20, "Р§РўРћ РЎРћРҐР РђРќРЇРўР¬", .content),
        .toggle(21, "text", "РЈРґР°Р»С‘РЅРЅС‹Р№ С‚РµРєСЃС‚", AyuGramSettings.saveDeletedText, .content),
        .toggle(22, "edits", "РСЃС‚РѕСЂРёСЏ РёР·РјРµРЅРµРЅРёР№", AyuGramSettings.editHistoryEnabled, .content),
        .toggle(23, "photos", "Р¤РѕС‚РѕРіСЂР°С„РёРё", AyuGramSettings.saveDeletedPhotos, .content),
        .toggle(24, "videos", "Р’РёРґРµРѕ Рё РІРёРґРµРѕСЃРѕРѕР±С‰РµРЅРёСЏ", AyuGramSettings.saveDeletedVideos, .content),
        .toggle(25, "voice", "Р“РѕР»РѕСЃРѕРІС‹Рµ СЃРѕРѕР±С‰РµРЅРёСЏ", AyuGramSettings.saveDeletedVoice, .content),
        .toggle(26, "files", "Р¤Р°Р№Р»С‹", AyuGramSettings.saveDeletedFiles, .content),
        .toggle(27, "stickers", "РЎС‚РёРєРµСЂС‹ Рё GIF", AyuGramSettings.saveDeletedStickers, .content),
        .toggle(28, "viewOnce", "РћРґРЅРѕСЂР°Р·РѕРІС‹Рµ С„РѕС‚Рѕ Рё РІРёРґРµРѕ", AyuGramSettings.preserveViewOnceMedia, .content),
        .header(40, "РРќР”РР’РР”РЈРђР›Р¬РќР«Р• РџР РђР’РР›Рђ", .rules),
        .action(41, "addAlways", "Р”РѕР±Р°РІРёС‚СЊ РІ В«Р’СЃРµРіРґР° СЃРѕС…СЂР°РЅСЏС‚СЊВ»", .rules),
        .action(42, "addNever", "Р”РѕР±Р°РІРёС‚СЊ РІ В«РќРёРєРѕРіРґР° РЅРµ СЃРѕС…СЂР°РЅСЏС‚СЊВ»", .rules)
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
    entries.append(.info(900, "РќР°Р¶Р°С‚РёРµ РЅР° РґРѕР±Р°РІР»РµРЅРЅС‹Р№ С‡Р°С‚ РїРµСЂРµРєР»СЋС‡Р°РµС‚: РІСЃРµРіРґР° в†’ РЅРёРєРѕРіРґР° в†’ РѕР±С‰РёРµ РЅР°СЃС‚СЂРѕР№РєРё.", .rules))

    let retentionText = AyuGramSettings.retentionDays == 0 ? "Р‘РµР· РѕРіСЂР°РЅРёС‡РµРЅРёСЏ" : "\(AyuGramSettings.retentionDays) РґРЅРµР№"
    let limitText = AyuGramSettings.vaultLimitMB == 0 ? "Р‘РµР· РѕРіСЂР°РЅРёС‡РµРЅРёСЏ" : "\(AyuGramSettings.vaultLimitMB) РњР‘"
    entries.append(contentsOf: [
        .header(1000, "РҐР РђРќРР›РР©Р•", .storage),
        .action(1001, "retention", "РЎСЂРѕРє С…СЂР°РЅРµРЅРёСЏ: \(retentionText)", .storage),
        .action(1002, "limit", "Р›РёРјРёС‚ РјРµРґРёР°: \(limitText)", .storage),
        .toggle(1003, "biometric", "Р—Р°С‰РёС‰Р°С‚СЊ С…СЂР°РЅРёР»РёС‰Рµ Face ID", AyuGramSettings.vaultBiometricLockEnabled, .storage),
        .info(1004, "Р›РёРјРёС‚ СѓРґР°Р»СЏРµС‚ СЃР°РјС‹Рµ СЃС‚Р°СЂС‹Рµ СЃРѕС…СЂР°РЅС‘РЅРЅС‹Рµ С„Р°Р№Р»С‹. РўРµРєСЃС‚РѕРІС‹Р№ Р°СЂС…РёРІ РѕС‡РёС‰Р°РµС‚СЃСЏ РїРѕ СЃСЂРѕРєСѓ С…СЂР°РЅРµРЅРёСЏ.", .storage),
        .header(1100, "РЈР’Р•Р”РћРњР›Р•РќРРЇ РћР‘ РЈР”РђР›Р•РќРР", .notifications),
        .toggle(1101, "noticePrivate", "Р›РёС‡РЅС‹Рµ С‡Р°С‚С‹", AyuGramSettings.notifyPrivateChats, .notifications),
        .toggle(1102, "noticeGroups", "Р“СЂСѓРїРїС‹", AyuGramSettings.notifyGroups, .notifications),
        .toggle(1103, "noticeChannels", "РљР°РЅР°Р»С‹", AyuGramSettings.notifyChannels, .notifications),
        .toggle(1104, "noticeBots", "Р‘РѕС‚С‹", AyuGramSettings.notifyBots, .notifications),
        .toggle(1105, "hideNotice", "РЎРєСЂС‹РІР°С‚СЊ С‚РµРєСЃС‚ СѓРІРµРґРѕРјР»РµРЅРёСЏ", AyuGramSettings.hideNotificationContent, .notifications),
        .info(1106, "РЎРёСЃС‚РµРјРЅРѕРµ СѓРІРµРґРѕРјР»РµРЅРёРµ РІРѕР·РјРѕР¶РЅРѕ, РїРѕРєР° iOS РїРѕР·РІРѕР»СЏРµС‚ sideload-РїСЂРёР»РѕР¶РµРЅРёСЋ СЂР°Р±РѕС‚Р°С‚СЊ РІ С„РѕРЅРµ. РџРѕСЃР»Рµ РїСЂРёРЅСѓРґРёС‚РµР»СЊРЅРѕРіРѕ Р·Р°РєСЂС‹С‚РёСЏ РѕР±РЅРѕРІР»РµРЅРёРµ РїСЂРёРґС‘С‚ РїСЂРё СЃР»РµРґСѓСЋС‰РµРј Р·Р°РїСѓСЃРєРµ.", .notifications)
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
        case "publicChannels": AyuGramSettings.savePublicChannels = value
        case "publicGroups": AyuGramSettings.savePublicGroups = value
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
        let title = rule == .always ? "Р’СЃРµРіРґР° СЃРѕС…СЂР°РЅСЏС‚СЊ" : "РќРёРєРѕРіРґР° РЅРµ СЃРѕС…СЂР°РЅСЏС‚СЊ"
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
            ItemListControllerState(presentationData: itemPresentationData, title: .text("РџСЂР°РІРёР»Р° AyuGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramRetentionEntries(peers: peers), style: .blocks, animateChanges: true), arguments)
        )
    }

    let controller = ItemListController(context: context, state: signal)
    holder.controller = controller
    refresh()
    return controller
}

