import Foundation
import UIKit
import LocalAuthentication
import UserNotifications
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import AlertUI
import PresentationDataUtils

private final class AyuGramSpyControllerArguments {
    let update: (AyuGramSpySetting, Bool) -> Void
    let cycleOpacity: () -> Void
    let cycleDeletedMark: () -> Void
    let openFilters: () -> Void
    let openVault: () -> Void
    let clearVault: () -> Void
    let clearArchive: () -> Void
    let testNotification: () -> Void

    init(update: @escaping (AyuGramSpySetting, Bool) -> Void, cycleOpacity: @escaping () -> Void, cycleDeletedMark: @escaping () -> Void, openFilters: @escaping () -> Void, openVault: @escaping () -> Void, clearVault: @escaping () -> Void, clearArchive: @escaping () -> Void, testNotification: @escaping () -> Void) {
        self.update = update
        self.cycleOpacity = cycleOpacity
        self.cycleDeletedMark = cycleDeletedMark
        self.openFilters = openFilters
        self.openVault = openVault
        self.clearVault = clearVault
        self.clearArchive = clearArchive
        self.testNotification = testNotification
    }
}

private final class AyuGramSpyControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramSpySetting {
    case antiRecall
    case editHistory
    case deletedMarker
    case deletionNotices
    case systemNotices
    case restricted
    case viewOnce
    case vault
    case localNotifications
    case backgroundKeepAlive
}

private enum AyuGramSpySection: Int32 {
    case deletion
    case media
    case notifications
}

private enum AyuGramSpyEntry: ItemListNodeEntry {
    case antiRecall(Bool)
    case editHistory(Bool)
    case deletedMarker(Bool)
    case deletedMark(String)
    case deletionNotices(Bool)
    case systemNotices(Bool)
    case opacity(Int)
    case filters
    case deletionFooter(String)
    case mediaHeader(String)
    case restricted(Bool)
    case viewOnce(Bool)
    case vault(Bool)
    case openVault(String)
    case clearVault(String)
    case clearArchive(String)
    case mediaFooter(String)
    case notificationsHeader(String)
    case localNotifications(Bool)
    case backgroundKeepAlive(Bool)
    case testNotification(String)
    case notificationsFooter(String)

    var section: ItemListSectionId {
        switch self {
        case .antiRecall, .editHistory, .deletedMarker, .deletedMark, .deletionNotices, .systemNotices, .opacity, .filters, .deletionFooter:
            return AyuGramSpySection.deletion.rawValue
        case .mediaHeader, .restricted, .viewOnce, .vault, .openVault, .clearVault, .clearArchive, .mediaFooter:
            return AyuGramSpySection.media.rawValue
        case .notificationsHeader, .localNotifications, .backgroundKeepAlive, .testNotification, .notificationsFooter:
            return AyuGramSpySection.notifications.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .antiRecall: return 0
        case .editHistory: return 1
        case .deletedMarker: return 2
        case .deletedMark: return 3
        case .deletionNotices: return 4
        case .systemNotices: return 5
        case .opacity: return 6
        case .filters: return 7
        case .deletionFooter: return 8
        case .mediaHeader: return 9
        case .restricted: return 10
        case .viewOnce: return 11
        case .vault: return 12
        case .openVault: return 13
        case .clearVault: return 14
        case .clearArchive: return 15
        case .mediaFooter: return 16
        case .notificationsHeader: return 17
        case .localNotifications: return 18
        case .backgroundKeepAlive: return 19
        case .testNotification: return 20
        case .notificationsFooter: return 21
        }
    }

    static func < (lhs: AyuGramSpyEntry, rhs: AyuGramSpyEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramSpyControllerArguments
        let strings = AyuGramStrings(languageCode: presentationData.strings.baseLanguageCode)
        switch self {
        case let .antiRecall(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.antiRecall, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.antiRecall, $0) })
        case let .editHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.editHistory, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.editHistory, $0) })
        case let .deletedMarker(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.deletedMarker, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.deletedMarker, $0) })
        case let .deletedMark(value):
            let title = value.isEmpty ? "—" : value
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: strings.deletedMark + ": " + title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.cycleDeletedMark)
        case let .deletionNotices(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.deletionNotices, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.deletionNotices, $0) })
        case let .systemNotices(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.systemNotices, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.systemNotices, $0) })
        case let .opacity(value):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: strings.opacity + ": \(value)%", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.cycleOpacity)
        case .filters:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: strings.filters, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.openFilters)
        case let .deletionFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .mediaHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .restricted(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.restricted, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.restricted, $0) })
        case let .viewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.viewOnce, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.viewOnce, $0) })
        case let .vault(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.vault, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.vault, $0) })
        case let .openVault(count):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: strings.openVault + " (" + count + ")", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.openVault)
        case let .clearVault(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.clearVault)
        case let .clearArchive(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.clearArchive)
        case let .mediaFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .notificationsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .localNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.localNotifications, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.localNotifications, $0) })
        case let .backgroundKeepAlive(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.backgroundKeepAlive, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.backgroundKeepAlive, $0) })
        case let .testNotification(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.testNotification)
        case let .notificationsFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayuGramPostTestNotification() {
    let strings = AyuGramStrings(languageCode: Locale.preferredLanguages.first ?? "en")
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        guard granted else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "AyuGram"
        content.body = strings.testNotificationBody
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ayugram.test", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

private func ayuGramSpyEntries(strings: AyuGramStrings) -> [AyuGramSpyEntry] {
    let storedCount = AyuGramSettings.lastKnownStoredItemCount
    return [
        .antiRecall(AyuGramSettings.antiRecallEnabled),
        .editHistory(AyuGramSettings.editHistoryEnabled),
        .deletedMarker(AyuGramSettings.showDeletedMessageMarker),
        .deletedMark(AyuGramSettings.deletedMark),
        .deletionNotices(AyuGramSettings.deletionNotificationsEnabled),
        .systemNotices(AyuGramSettings.systemDeletionNotificationsEnabled),
        .opacity(Int((AyuGramSettings.deletedMessageOpacity * 100.0).rounded())),
        .filters,
        .deletionFooter(strings.spyFooter),
        .mediaHeader(strings.mediaHeader),
        .restricted(AyuGramSettings.saveRestrictedContent),
        .viewOnce(AyuGramSettings.preserveViewOnceMedia),
        .vault(AyuGramSettings.vaultEnabled),
        .openVault("\(storedCount)"),
        .clearVault(strings.clearVault),
        .clearArchive(strings.clearArchive),
        .mediaFooter(strings.mediaFooter),
        .notificationsHeader(strings.notificationsHeader),
        .localNotifications(AyuGramSettings.localNotificationsEnabled),
        .backgroundKeepAlive(AyuGramSettings.backgroundKeepAliveEnabled),
        .testNotification(strings.testNotification),
        .notificationsFooter(strings.notificationsFooter)
    ]
}

public func ayuGramSpyController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let controllerHolder = AyuGramSpyControllerHolder()

    // The stored item count is kept in a cached setting so that opening the
    // screen never scans the vault and archive directories on the main thread.
    DispatchQueue.global(qos: .utility).async {
        let count = AyuGramVaultStore.items().count + AyuGramArchiveStore.records().count
        AyuGramSettings.lastKnownStoredItemCount = count
    }

    let refresh: () -> Void = {
        revision.set(revisionValue.modify { value in
            return value + 1
        })
    }

    let presentVault: () -> Void = {
        controllerHolder.controller?.push(ayuGramVaultController(context: context))
    }

    let strings = AyuGramStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)

    let confirmClear: (String, String, @escaping () -> Void) -> Void = { title, text, action in
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: title,
            text: text,
            actions: [
                TextAlertAction(type: .destructiveAction, title: strings.clearConfirm, action: {
                    action()
                    refresh()
                }),
                TextAlertAction(type: .defaultAction, title: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Cancel, action: {})
            ]
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    }

    let arguments = AyuGramSpyControllerArguments(update: { setting, value in
        switch setting {
        case .antiRecall: AyuGramSettings.antiRecallEnabled = value
        case .editHistory: AyuGramSettings.editHistoryEnabled = value
        case .deletedMarker: AyuGramSettings.showDeletedMessageMarker = value
        case .deletionNotices: AyuGramSettings.deletionNotificationsEnabled = value
        case .systemNotices:
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
        case .restricted: AyuGramSettings.saveRestrictedContent = value
        case .viewOnce: AyuGramSettings.preserveViewOnceMedia = value
        case .vault: AyuGramSettings.vaultEnabled = value
        case .localNotifications:
            AyuGramSettings.localNotificationsEnabled = value
            if value {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if !granted {
                        AyuGramSettings.localNotificationsEnabled = false
                        DispatchQueue.main.async {
                            refresh()
                        }
                    }
                }
            }
        case .backgroundKeepAlive: AyuGramSettings.backgroundKeepAliveEnabled = value
        }
        refresh()
    }, cycleOpacity: {
        let current = AyuGramSettings.deletedMessageOpacity
        if current < 0.475 {
            AyuGramSettings.deletedMessageOpacity = 0.55
        } else if current < 0.625 {
            AyuGramSettings.deletedMessageOpacity = 0.70
        } else {
            AyuGramSettings.deletedMessageOpacity = 0.40
        }
        refresh()
    }, cycleDeletedMark: {
        AyuGramSettings.deletedMarkPreset = (AyuGramSettings.deletedMarkPreset + 1) % AyuGramSettings.deletedMarkPresetCount
        refresh()
    }, openFilters: {
        controllerHolder.controller?.push(ayuGramRetentionController(context: context))
    }, openVault: {
        guard AyuGramSettings.vaultBiometricLockEnabled else {
            presentVault()
            return
        }
        let authentication = LAContext()
        var error: NSError?
        guard authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let alert = UIAlertController(title: strings.biometricTitle, message: strings.biometricUnavailable, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            controllerHolder.controller?.present(alert, animated: true)
            return
        }
        authentication.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: strings.biometricReason) { success, _ in
            if success {
                DispatchQueue.main.async(execute: presentVault)
            }
        }
    }, clearVault: {
        confirmClear(strings.clearVault, strings.clearVaultText, {
            AyuGramVaultStore.removeAll()
        })
    }, clearArchive: {
        confirmClear(strings.clearArchive, strings.clearArchiveText, {
            AyuGramArchiveStore.removeAll()
        })
    }, testNotification: {
        ayuGramPostTestNotification()
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = AyuGramStrings(languageCode: presentationData.strings.baseLanguageCode)
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: itemPresentationData, title: .text(strings.spy), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramSpyEntries(strings: strings), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerHolder.controller = controller
    controller.navigationPresentation = .modal
    return controller
}
