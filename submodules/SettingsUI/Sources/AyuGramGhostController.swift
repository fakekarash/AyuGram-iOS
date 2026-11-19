import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private final class AyuGramGhostControllerArguments {
    let update: (AyuGramGhostSetting, Bool) -> Void

    init(update: @escaping (AyuGramGhostSetting, Bool) -> Void) {
        self.update = update
    }
}

private final class AyuGramGhostControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramGhostSetting {
    case enabled
    case reads
    case markReadAfterSend
    case stories
    case typing
    case offline
}

private enum AyuGramGhostSection: Int32 {
    case master
    case details
    case footer
}

private enum AyuGramGhostEntry: ItemListNodeEntry {
    case master(Bool)
    case detailsHeader(String)
    case reads(Bool)
    case markReadAfterSend(Bool)
    case stories(Bool)
    case typing(Bool)
    case offline(Bool)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .master:
            return AyuGramGhostSection.master.rawValue
        case .detailsHeader, .reads, .markReadAfterSend, .stories, .typing, .offline:
            return AyuGramGhostSection.details.rawValue
        case .footer:
            return AyuGramGhostSection.footer.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .master: return 0
        case .detailsHeader: return 1
        case .reads: return 2
        case .markReadAfterSend: return 3
        case .stories: return 4
        case .typing: return 5
        case .offline: return 6
        case .footer: return 7
        }
    }

    static func < (lhs: AyuGramGhostEntry, rhs: AyuGramGhostEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramGhostControllerArguments
        let strings = AyuGramStrings(languageCode: presentationData.strings.baseLanguageCode)
        let masterEnabled = AyuGramSettings.ghostModeEnabled
        switch self {
        case let .master(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.ghostMaster, value: value, sectionId: self.section, style: .blocks, updated: { arguments.update(.enabled, $0) })
        case let .detailsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .markReadAfterSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.markReadAfterSend, value: value, enabled: masterEnabled, sectionId: self.section, style: .blocks, updated: { arguments.update(.markReadAfterSend, $0) })
        case let .reads(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideReads, value: value, enabled: masterEnabled, sectionId: self.section, style: .blocks, updated: { arguments.update(.reads, $0) })
        case let .stories(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideStories, value: value, enabled: masterEnabled, sectionId: self.section, style: .blocks, updated: { arguments.update(.stories, $0) })
        case let .typing(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideTyping, value: value, enabled: masterEnabled, sectionId: self.section, style: .blocks, updated: { arguments.update(.typing, $0) })
        case let .offline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.stayOffline, value: value, enabled: masterEnabled, sectionId: self.section, style: .blocks, updated: { arguments.update(.offline, $0) })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayuGramGhostEntries(strings: AyuGramStrings) -> [AyuGramGhostEntry] {
    return [
        .master(AyuGramSettings.ghostModeEnabled),
        .detailsHeader(strings.ghostHeader),
        .reads(AyuGramSettings.hideReadReceiptsOption),
        .markReadAfterSend(AyuGramSettings.markReadAfterSend),
        .stories(AyuGramSettings.hideStoryViewsOption),
        .typing(AyuGramSettings.hideTypingOption),
        .offline(AyuGramSettings.stayOfflineOption),
        .footer(strings.ghostFooter)
    ]
}

public func ayuGramGhostController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let controllerHolder = AyuGramGhostControllerHolder()

    let refresh: () -> Void = {
        revision.set(revisionValue.modify { value in
            return value + 1
        })
    }

    let arguments = AyuGramGhostControllerArguments(update: { setting, value in
        switch setting {
        case .enabled: AyuGramSettings.ghostModeEnabled = value
        case .reads: AyuGramSettings.hideReadReceiptsOption = value
        case .markReadAfterSend: AyuGramSettings.markReadAfterSend = value
        case .stories: AyuGramSettings.hideStoryViewsOption = value
        case .typing: AyuGramSettings.hideTypingOption = value
        case .offline: AyuGramSettings.stayOfflineOption = value
        }
        refresh()
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = AyuGramStrings(languageCode: presentationData.strings.baseLanguageCode)
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: itemPresentationData, title: .text(strings.ghostMode), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramGhostEntries(strings: strings), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerHolder.controller = controller
    controller.navigationPresentation = .modal
    return controller
}
