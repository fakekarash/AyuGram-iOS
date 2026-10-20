import Foundation
import UIKit
import QuickLook
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import AlertUI
import PresentationDataUtils

private final class AyuGramVaultPreviewController: QLPreviewController, QLPreviewControllerDataSource {
    private let previewURL: URL

    init(url: URL) {
        self.previewURL = url
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.previewURL as NSURL
    }
}

private final class AyuGramVaultControllerArguments {
    let open: (AyuGramVaultItem) -> Void
    let openArchive: (AyuGramArchiveRecord) -> Void
    let cycleFilter: () -> Void
    let search: () -> Void
    let clearAll: () -> Void

    init(open: @escaping (AyuGramVaultItem) -> Void, openArchive: @escaping (AyuGramArchiveRecord) -> Void, cycleFilter: @escaping () -> Void, search: @escaping () -> Void, clearAll: @escaping () -> Void) {
        self.open = open
        self.openArchive = openArchive
        self.cycleFilter = cycleFilter
        self.search = search
        self.clearAll = clearAll
    }
}

private enum AyuGramVaultFilter: Int32 {
    case all
    case deleted
    case edited
    case media

    var title: String {
        switch self {
        case .all: return "Все"
        case .deleted: return "Удалённые"
        case .edited: return "Изменённые"
        case .media: return "Медиа"
        }
    }

    var next: AyuGramVaultFilter {
        return AyuGramVaultFilter(rawValue: self.rawValue + 1) ?? .all
    }
}

private final class AyuGramVaultControllerHolder {
    weak var controller: ItemListController?
}

private enum AyuGramVaultSection: Int32 {
    case summary
    case controls
    case files
    case archive
    case actions
}

private enum AyuGramVaultEntry: ItemListNodeEntry {
    case summary(String)
    case filter(String)
    case search(String)
    case empty
    case file(Int32, AyuGramVaultItem, String)
    case archiveHeader
    case archive(Int32, AyuGramArchiveRecord, String)
    case clearAll

    var section: ItemListSectionId {
        switch self {
        case .summary:
            return AyuGramVaultSection.summary.rawValue
        case .filter, .search:
            return AyuGramVaultSection.controls.rawValue
        case .empty, .file:
            return AyuGramVaultSection.files.rawValue
        case .archiveHeader, .archive:
            return AyuGramVaultSection.archive.rawValue
        case .clearAll:
            return AyuGramVaultSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .summary:
            return 0
        case .filter:
            return 2
        case .search:
            return 3
        case .empty:
            return 1
        case let .file(index, _, _):
            return 100 + index
        case .archiveHeader:
            return 10_000
        case let .archive(index, _, _):
            return 10_100 + index
        case .clearAll:
            return Int32.max
        }
    }

    static func < (lhs: AyuGramVaultEntry, rhs: AyuGramVaultEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramVaultControllerArguments
        switch self {
        case let .summary(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .filter(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Фильтр: \(title)", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.cycleFilter)
        case let .search(query):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: query.isEmpty ? "Поиск" : "Поиск: \(query)", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.search)
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Нет записей для выбранного фильтра или поискового запроса."), sectionId: self.section)
        case let .file(_, item, title):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.open(item) }
            )
        case .archiveHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "АРХИВ СООБЩЕНИЙ", sectionId: self.section)
        case let .archive(_, record, title):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.openArchive(record) }
            )
        case .clearAll:
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Очистить хранилище",
                kind: .destructive,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: arguments.clearAll
            )
        }
    }
}

private func ayuGramVaultEntries(filter: AyuGramVaultFilter, query: String) -> [AyuGramVaultEntry] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let allItems = AyuGramVaultStore.items()
    let allRecords = AyuGramArchiveStore.records()
    let items = allItems.filter { item in
        guard filter == .all || filter == .media else { return false }
        guard !normalizedQuery.isEmpty else { return true }
        return [item.originalFilename, item.storedFilename, item.peerTitle, item.authorTitle]
            .compactMap { $0 }.joined(separator: " ").lowercased().contains(normalizedQuery)
    }
    let records = allRecords.filter { record in
        if filter == .media { return false }
        if filter == .deleted && !record.isDeleted { return false }
        if filter == .edited && (record.previousTexts.isEmpty || record.isDeleted) { return false }
        guard !normalizedQuery.isEmpty else { return true }
        return ([record.text, record.peerTitle ?? "", record.authorTitle ?? ""] + record.previousTexts + (record.mediaKinds ?? []))
            .joined(separator: " ").lowercased().contains(normalizedQuery)
    }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file

    var result: [AyuGramVaultEntry] = [
        .summary("Файлов: \(allItems.count) · \(formatter.string(fromByteCount: allItems.reduce(0) { $0 + $1.byteCount }))\nЗаписей сообщений: \(allRecords.count)\nПоказано: \(items.count + records.count). Все данные находятся только на этом устройстве."),
        .filter(filter.title),
        .search(query)
    ]
    if items.isEmpty && records.isEmpty {
        result.append(.empty)
    } else if !items.isEmpty {
        for (index, item) in items.enumerated() {
            let name = item.originalFilename ?? item.storedFilename
            let size = formatter.string(fromByteCount: item.byteCount)
            let chat = item.peerTitle.map { "\($0) · " } ?? ""
            result.append(.file(Int32(index), item, "\(chat)\(item.kind.title): \(name) · \(size)"))
        }
    }
    if !records.isEmpty {
        result.append(.archiveHeader)
        for (index, record) in records.enumerated() {
            let normalized = record.text.replacingOccurrences(of: "\n", with: " ")
            let preview = normalized.isEmpty ? "медиа или сообщение без текста" : String(normalized.prefix(72))
            let kind = record.isDeleted ? "Удалено" : "Изменено"
            let chat = record.peerTitle.map { "\($0) · " } ?? ""
            result.append(.archive(Int32(index), record, "\(chat)\(kind): \(preview)"))
        }
    }
    if !allItems.isEmpty || !allRecords.isEmpty {
        result.append(.clearAll)
    }
    return result
}

public func ayuGramVaultController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int32>(0, ignoreRepeated: false)
    let revisionValue = Atomic<Int32>(value: 0)
    let filterValue = Atomic<AyuGramVaultFilter>(value: .all)
    let queryValue = Atomic<String>(value: "")
    let controllerHolder = AyuGramVaultControllerHolder()

    let refresh: () -> Void = {
        revision.set(revisionValue.modify { $0 + 1 })
    }

    let arguments = AyuGramVaultControllerArguments(open: { item in
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let title = item.originalFilename ?? item.storedFilename
        var details = "\(item.kind.title)\n\(formatter.string(fromByteCount: item.byteCount))"
        if let peerTitle = item.peerTitle {
            details += "\nЧат: \(peerTitle)"
        }
        if let authorTitle = item.authorTitle, authorTitle != item.peerTitle {
            details += "\nАвтор: \(authorTitle)"
        }
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: title,
            text: details,
            actions: [
                TextAlertAction(type: .defaultAction, title: "Просмотреть", action: {
                    Queue.mainQueue().after(0.2) {
                        guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                            return
                        }
                        let preview = AyuGramVaultPreviewController(url: item.fileURL)
                        controllerHolder.controller?.present(preview, animated: true, completion: nil)
                    }
                }),
                TextAlertAction(type: .genericAction, title: "Поделиться", action: {
                    Queue.mainQueue().after(0.2) {
                        let share = UIActivityViewController(activityItems: [item.fileURL], applicationActivities: nil)
                        if let popover = share.popoverPresentationController, let view = controllerHolder.controller?.view {
                            popover.sourceView = view
                            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1.0, height: 1.0)
                        }
                        controllerHolder.controller?.present(share, animated: true, completion: nil)
                    }
                }),
                TextAlertAction(type: .destructiveAction, title: "Удалить", action: {
                    AyuGramVaultStore.remove(item)
                    refresh()
                }),
                TextAlertAction(type: .destructiveAction, title: "Очистить этот чат", action: {
                    AyuGramVaultStore.remove(peerId: item.peerId)
                    AyuGramArchiveStore.remove(peerId: item.peerId)
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ],
            actionLayout: .vertical
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    }, openArchive: { record in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        var lines: [String] = []
        if let peerTitle = record.peerTitle {
            lines.append("Чат: \(peerTitle)")
        }
        if let authorTitle = record.authorTitle, authorTitle != record.peerTitle {
            lines.append("Автор: \(authorTitle)")
        }
        if let mediaKinds = record.mediaKinds, !mediaKinds.isEmpty {
            lines.append("Медиа: \(mediaKinds.joined(separator: ", "))")
        }
        lines.append("ID чата: \(record.peerId) · ID сообщения: \(record.messageId)")
        if record.isDeleted {
            lines.append("Удалено: " + dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(record.deletionTimestamp))))
        }
        lines.append("Текущий текст:\n" + (record.text.isEmpty ? "[без текста]" : record.text))
        if !record.previousTexts.isEmpty {
            lines.append("Предыдущие версии:")
            for (index, text) in record.previousTexts.enumerated() {
                lines.append("\(index + 1). " + (text.isEmpty ? "[без текста]" : text))
            }
        }
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: record.isDeleted ? "Удалённое сообщение" : "История изменений",
            text: lines.joined(separator: "\n\n"),
            actions: [
                TextAlertAction(type: .defaultAction, title: "Поделиться", action: {
                    Queue.mainQueue().after(0.2) {
                        let share = UIActivityViewController(activityItems: [lines.joined(separator: "\n\n")], applicationActivities: nil)
                        if let popover = share.popoverPresentationController, let view = controllerHolder.controller?.view {
                            popover.sourceView = view
                            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1.0, height: 1.0)
                        }
                        controllerHolder.controller?.present(share, animated: true, completion: nil)
                    }
                }),
                TextAlertAction(type: .defaultAction, title: "Копировать", action: {
                    UIPasteboard.general.string = lines.joined(separator: "\n\n")
                }),
                TextAlertAction(type: .destructiveAction, title: "Очистить этот чат", action: {
                    AyuGramVaultStore.remove(peerId: record.peerId)
                    AyuGramArchiveStore.remove(peerId: record.peerId)
                    refresh()
                }),
                TextAlertAction(type: .destructiveAction, title: "Удалить запись", action: {
                    AyuGramArchiveStore.remove(record)
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ],
            actionLayout: .vertical
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    }, cycleFilter: {
        _ = filterValue.modify { $0.next }
        revision.set(revisionValue.modify { $0 + 1 })
    }, search: {
        let alert = UIAlertController(title: "Поиск в хранилище", message: "Введите чат, автора, текст или имя файла.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = queryValue.with { $0 }
            textField.placeholder = "Поиск"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { _ in
            _ = queryValue.swap("")
            revision.set(revisionValue.modify { $0 + 1 })
        }))
        alert.addAction(UIAlertAction(title: "Найти", style: .default, handler: { _ in
            _ = queryValue.swap(alert.textFields?.first?.text ?? "")
            revision.set(revisionValue.modify { $0 + 1 })
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        controllerHolder.controller?.present(alert, animated: true)
    }, clearAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alert = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: "Очистить хранилище AyuGram?",
            text: "Все сохранённые медиа, удалённые сообщения и история изменений будут удалены с этого устройства.",
            actions: [
                TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                    AyuGramVaultStore.removeAll()
                    AyuGramArchiveStore.removeAll()
                    refresh()
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ]
        )
        controllerHolder.controller?.present(alert, in: .window(.root))
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let itemPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(
            presentationData: itemPresentationData,
            title: .text("Хранилище AyuGram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: itemPresentationData,
            entries: ayuGramVaultEntries(filter: filterValue.with { $0 }, query: queryValue.with { $0 }),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let result = ItemListController(context: context, state: signal)
    controllerHolder.controller = result
    return result
}
