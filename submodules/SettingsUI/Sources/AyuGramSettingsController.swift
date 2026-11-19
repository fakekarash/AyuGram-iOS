import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private final class AyuGramSettingsControllerArguments {
    let openGhost: () -> Void
    let openSpy: () -> Void
    let openFilters: () -> Void
    let openUrl: (String) -> Void

    init(openGhost: @escaping () -> Void, openSpy: @escaping () -> Void, openFilters: @escaping () -> Void, openUrl: @escaping (String) -> Void) {
        self.openGhost = openGhost
        self.openSpy = openSpy
        self.openFilters = openFilters
        self.openUrl = openUrl
    }
}

private final class AyuGramSettingsControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramSettingsSection: Int32 {
    case header
    case categories
    case links
    case footer
}

private enum AyuGramSettingsEntry: ItemListNodeEntry {
    case header
    case categoriesHeader(String)
    case ghost(String, String)
    case spy(String, String)
    case filters(String, String)
    case linksHeader(String)
    case channel(String)
    case chats(String)
    case translation(String)
    case github(String)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .header:
            return AyuGramSettingsSection.header.rawValue
        case .categoriesHeader, .ghost, .spy, .filters:
            return AyuGramSettingsSection.categories.rawValue
        case .linksHeader, .channel, .chats, .translation, .github:
            return AyuGramSettingsSection.links.rawValue
        case .footer:
            return AyuGramSettingsSection.footer.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .header: return 0
        case .categoriesHeader: return 1
        case .ghost: return 2
        case .spy: return 3
        case .filters: return 4
        case .linksHeader: return 5
        case .channel: return 6
        case .chats: return 7
        case .translation: return 8
        case .github: return 9
        case .footer: return 10
        }
    }

    static func < (lhs: AyuGramSettingsEntry, rhs: AyuGramSettingsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    private func categoryIcon(name: String, presentationData: ItemListPresentationData) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22.0, weight: .regular)
        return UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(presentationData.theme.list.itemPrimaryTextColor, renderingMode: .alwaysOriginal)
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramSettingsControllerArguments
        switch self {
        case .header:
            return AyuGramHeaderItem(presentationData: presentationData, sectionId: self.section)
        case let .categoriesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .ghost(title, _):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: self.categoryIcon(name: "moon.fill", presentationData: presentationData), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openGhost()
            })
        case let .spy(title, _):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: self.categoryIcon(name: "eye.slash.fill", presentationData: presentationData), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openSpy()
            })
        case let .filters(title, _):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: self.categoryIcon(name: "line.3.horizontal.decrease.circle.fill", presentationData: presentationData), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openFilters()
            })
        case let .linksHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .channel(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openUrl("https://t.me/neAyuGramipa")
            })
        case let .chats(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openUrl("https://t.me/ayugramchat")
            })
        case let .translation(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openUrl("https://translate.ayugram.one")
            })
        case let .github(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openUrl("https://github.com/fakekarash/AyuGram-iOS")
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, textSize: .larger, textAlignment: .center)
        }
    }
}

private func ayuGramSettingsEntries(strings: AyuGramStrings) -> [AyuGramSettingsEntry] {
    let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    return [
        .header,
        .categoriesHeader(strings.categories),
        .ghost(strings.ghostMode, strings.ghostModeSubtitle),
        .spy(strings.spy, strings.spySubtitle),
        .filters(strings.filters, strings.filtersSubtitle),
        .linksHeader(strings.links),
        .channel(strings.channel),
        .chats(strings.chats),
        .translation(strings.translation),
        .github(strings.github),
        .footer(strings.versionFooter + " " + version)
    ]
}

public func ayuGramSettingsController(context: AccountContext) -> ViewController {
    let controllerHolder = AyuGramSettingsControllerHolder()

    let arguments = AyuGramSettingsControllerArguments(openGhost: {
        controllerHolder.controller?.push(ayuGramGhostController(context: context))
    }, openSpy: {
        controllerHolder.controller?.push(ayuGramSpyController(context: context))
    }, openFilters: {
        controllerHolder.controller?.push(ayuGramRetentionController(context: context))
    }, openUrl: { url in
        context.sharedContext.applicationBindings.openUrl(url)
    })

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = AyuGramStrings(languageCode: presentationData.strings.baseLanguageCode)
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: itemPresentationData, title: .text(strings.appName), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: itemPresentationData, entries: ayuGramSettingsEntries(strings: strings), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerHolder.controller = controller
    controller.navigationPresentation = .modal
    return controller
}

